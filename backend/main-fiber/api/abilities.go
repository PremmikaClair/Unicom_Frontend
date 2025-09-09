package api

import (
	"strings"


	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

// ---- collections
func membershipsColl() *mongo.Collection { return config.DB.Collection("memberships") }
func policiesColl() *mongo.Collection    { return config.DB.Collection("policies") }

// ---- auth extractor (use SAME secret as auth.go)
func userIDFromBearer(c *fiber.Ctx) (primitive.ObjectID, error) {
	auth := c.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		return primitive.NilObjectID, fiber.NewError(fiber.StatusUnauthorized, "missing token")
	}
	tok := strings.TrimPrefix(auth, "Bearer ")
	claims := jwt.MapClaims{}
	t, err := jwt.ParseWithClaims(tok, claims, func(t *jwt.Token) (interface{}, error) {
		return jwtSecret(), nil // <- from auth.go (same package)
	})
	if err != nil || !t.Valid {
		return primitive.NilObjectID, fiber.NewError(fiber.StatusUnauthorized, "invalid token")
	}
	sub, _ := claims["sub"].(string)
	return primitive.ObjectIDFromHex(sub)
}

type membershipDoc struct {
	UserID      primitive.ObjectID `bson:"user_id"`
	OrgPath     string             `bson:"org_path"`
	PositionKey string             `bson:"position_key"`
}

type abilitiesResp struct {
	OrgPath   string          `json:"org_path"`
	Abilities map[string]bool `json:"abilities"`
	Version   string          `json:"version,omitempty"`
}

// GET /api/abilities?org_path=/club/cpsk[&actions=event:create,post:create]
func GetAbilities(c *fiber.Ctx) error {
	orgPath := strings.TrimSpace(c.Query("org_path"))
	if orgPath == "" {
		return fiber.NewError(fiber.StatusBadRequest, "org_path is required")
	}
	// optional filter
	var requested []string
	if s := strings.TrimSpace(c.Query("actions")); s != "" {
		for _, a := range strings.Split(s, ",") {
			if a = strings.TrimSpace(a); a != "" {
				requested = append(requested, a)
			}
		}
	}
	// default pack if not provided
	if len(requested) == 0 {
		requested = []string{"post:create", "event:create", "post:moderate"}
	}

	userID, err := userIDFromBearer(c)
	if err != nil {
		return err
	}

	ctx, cancel := ctx10()
	defer cancel()

	// 1) load memberships for user
	var mems []membershipDoc
	cur, err := membershipsColl().Find(ctx, bson.M{"user_id": userID})
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	if err := cur.All(ctx, &mems); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "decode error")
	}

	// 2) load policies for user positions (enabled)
	posSet := map[string]struct{}{}
	for _, m := range mems {
		posSet[m.PositionKey] = struct{}{}
	}
	posArr := make([]string, 0, len(posSet))
	for k := range posSet {
		posArr = append(posArr, k)
	}
	polFilter := bson.M{"enabled": true}
	if len(posArr) > 0 {
		polFilter["position_key"] = bson.M{"$in": posArr}
	}
	pcur, err := policiesColl().Find(ctx, polFilter)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	var pols []Policy
	if err := pcur.All(ctx, &pols); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "decode error")
	}

	// 3) evaluate
	allowed := map[string]bool{}
	for _, a := range requested {
		allowed[a] = false
	}
	for _, m := range mems {
		for _, p := range pols {
			// match policy to membership by position + prefix
			if p.PositionKey != m.PositionKey {
				continue
			}
			if !strings.HasPrefix(m.OrgPath, p.Where.OrgPrefix) {
				continue
			}
			// action present?
			hasAction := false
			for _, pa := range p.Actions {
				if pa == "*" || pa == requested[0] { // fast path
					hasAction = true
					break
				}
			}
			// (we need per-action check below anyway)
			for _, req := range requested {
				if !contains(p.Actions, req) {
					continue
				}
				switch p.Scope {
				case "exact":
					if orgPath == m.OrgPath {
						allowed[req] = true
					}
				case "subtree":
					if strings.HasPrefix(orgPath, m.OrgPath) {
						allowed[req] = true
					}
				default: // treat unknown as exact
					if orgPath == m.OrgPath {
						allowed[req] = true
					}
				}
			}
			_ = hasAction // keep var for possible diagnostics
		}
	}

	return c.JSON(abilitiesResp{
		OrgPath:   orgPath,
		Abilities: allowed,
		Version:   "pol-v2",
	})
}

// ---- Where can I perform an action? (compact list)

// GET /api/abilities/where?action=event:create
func WhereAbilities(c *fiber.Ctx) error {
	action := strings.TrimSpace(c.Query("action"))
	if action == "" {
		return fiber.NewError(fiber.StatusBadRequest, "action is required")
	}
	userID, err := userIDFromBearer(c)
	if err != nil {
		return err
	}

	ctx, cancel := ctx10()
	defer cancel()

	var mems []membershipDoc
	cur, err := membershipsColl().Find(ctx, bson.M{"user_id": userID})
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	if err := cur.All(ctx, &mems); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "decode error")
	}

	posSet := map[string]struct{}{}
	for _, m := range mems {
		posSet[m.PositionKey] = struct{}{}
	}
	posArr := make([]string, 0, len(posSet))
	for k := range posSet {
		posArr = append(posArr, k)
	}
	pcur, err := policiesColl().Find(ctx, bson.M{
		"enabled":      true,
		"position_key": bson.M{"$in": posArr},
		"actions":      action,
	})
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	var pols []Policy
	if err := pcur.All(ctx, &pols); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "decode error")
	}

	// produce list of org_paths where the user can act
	type grant struct {
		OrgPath string `json:"org_path"`
	}
	seen := map[string]struct{}{}
	out := []grant{}

	for _, m := range mems {
		for _, p := range pols {
			if p.PositionKey != m.PositionKey {
				continue
			}
			if !strings.HasPrefix(m.OrgPath, p.Where.OrgPrefix) {
				continue
			}
			// We return the membership node as the org where creation is anchored.
			// (scope is enforced server-side on mutate; we don't need to expose it)
			if _, ok := seen[m.OrgPath]; !ok {
				seen[m.OrgPath] = struct{}{}
				out = append(out, grant{OrgPath: m.OrgPath})
			}
		}
	}

	return c.JSON(fiber.Map{
		"action": action,
		"orgs":   out,
		"version": "pol-v2",
	})
}

func contains(arr []string, x string) bool {
	for _, a := range arr {
		if a == x {
			return true
		}
	}
	return false
}

// Register route in your main routes wiring:
// router.Get("/abilities", GetAbilities)