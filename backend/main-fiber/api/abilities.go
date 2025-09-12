package api

import (
    "strings"

    "github.com/gofiber/fiber/v2"
    "github.com/pllus/main-fiber/config"
    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
)

// ---- collections
func membershipsColl() *mongo.Collection { return config.DB.Collection("memberships") }
func policiesColl() *mongo.Collection    { return config.DB.Collection("policies") }

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
// @Summary      Get user abilities for an org path
// @Description  Returns allowed actions for the user in the specified org path
// @Tags         abilities
// @Accept       json
// @Produce      json
// @Param        org_path  query     string  true  "Organization path"
// @Param        actions   query     string  false "Comma-separated actions to check"
// @Success      200       {object}  abilitiesResp
// @Router       /api/abilities [get]
func GetAbilities(c *fiber.Ctx) error {
    orgPath := strings.TrimSpace(c.Query("org_path"))
    if orgPath == "" {
        return fiber.NewError(fiber.StatusBadRequest, "org_path is required")
    }

    // fixed action set for UI
    actions := []string{"membership:assign","membership:revoke","position:create","policy:write","event:create","event:manage","post:create","post:moderate"}

    userID, err := userIDFromBearer(c)
    if err != nil { return err }

    ctx, cancel := ctx10(); defer cancel()
    allowed, err := AbilitiesFor(ctx, userID, orgPath, actions)
    if err != nil { return fiber.NewError(fiber.StatusInternalServerError, "abilities failed") }

    return c.JSON(abilitiesResp{ OrgPath: orgPath, Abilities: allowed, Version: "pol-v2" })
}

// ---- Where can I perform an action? (compact list)

// GET /api/abilities/where?action=event:create
// @Summary      List org paths where user can perform an action
// @Description  Returns org paths where the user has permission for the specified action
// @Tags         abilities
// @Accept       json
// @Produce      json
// @Param        action  query     string  true  "Action to check"
// @Success      200     {object}  map[string]interface{}
// @Router       /api/abilities/where [get]
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
