package api

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

/*
Policy model (scoped + prefix-based)

- where.org_prefix: which membership org paths this policy attaches to
- scope: how far the allow spreads from the *membership* node
    "exact"   → only that node
    "subtree" → node + all descendants
- actions: fully-qualified strings like "post:create", "event:create"
- effect: "allow" (deny reserved for later)
- enabled: toggle
*/
type PolicyWhere struct {
	OrgPrefix string `bson:"org_prefix" json:"org_prefix"` // e.g. "/faculty/"
}
type Policy struct {
	Key         string     `bson:"key,omitempty"          json:"key,omitempty"`
	PositionKey string     `bson:"position_key"           json:"position_key"` // e.g. "head"
	Where       PolicyWhere`bson:"where"                  json:"where"`
	Scope       string     `bson:"scope"                  json:"scope"`        // "exact" | "subtree"
	Effect      string     `bson:"effect"                 json:"effect"`       // "allow"
	Actions     []string   `bson:"actions"                json:"actions"`
	Enabled     bool       `bson:"enabled"                json:"enabled"`
	CreatedAt   time.Time  `bson:"created_at"             json:"created_at"`
}

func policyCol() *mongo.Collection { return config.DB.Collection("policies") }

// GET /policies?org_prefix=/faculty/&position_key=head
// @Summary      List policies
// @Description  List policies with optional filters
// @Tags         policies
// @Accept       json
// @Produce      json
// @Param        org_prefix    query     string  false "Organization prefix"
// @Param        position_key  query     string  false "Position key"
// @Success      200  {array}   Policy
// @Failure      500  {string}  string "DB error or decode error"
// @Router       /policies [get]
func ListPolicies(c *fiber.Ctx) error {
	filter := bson.M{}
	if p := strings.TrimSpace(c.Query("org_prefix")); p != "" {
		filter["where.org_prefix"] = p
	}
	if k := strings.TrimSpace(c.Query("position_key")); k != "" {
		filter["position_key"] = k
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cur, err := policyCol().Find(ctx, filter)
	if err != nil {
		log.Println("policies find error:", err)
		return c.Status(500).SendString("DB error")
	}
	defer cur.Close(ctx)

	var items []Policy
	if err := cur.All(ctx, &items); err != nil {
		return c.Status(500).SendString("decode error")
	}
	if items == nil {
		items = []Policy{}
	}
	return c.JSON(items)
}

// POST /policies
// @Summary      Create policy
// @Description  Create a new policy
// @Tags         policies
// @Accept       json
// @Produce      json
// @Param        Policy  body      Policy  true  "Policy info"
// @Success      201  {object}  Policy
// @Failure      400  {string}  string "Invalid body or missing fields"
// @Failure      500  {string}  string "Insert failed"
// @Router       /policies [post]
func CreatePolicy(c *fiber.Ctx) error {
    var in Policy
    if err := c.BodyParser(&in); err != nil {
        return c.Status(400).SendString("invalid body")
    }
	in.Where.OrgPrefix = strings.TrimSpace(in.Where.OrgPrefix)
	in.PositionKey = strings.TrimSpace(in.PositionKey)
	if in.Where.OrgPrefix == "" || in.PositionKey == "" || len(in.Actions) == 0 {
		return c.Status(400).SendString("org_prefix, position_key, actions required")
	}
	if in.Scope == "" {
		in.Scope = "exact"
	}
	if in.Effect == "" {
		in.Effect = "allow"
	}
	if !in.Enabled {
		in.Enabled = true
	}
    in.CreatedAt = time.Now()

    // authz: require policy:write at where.org_prefix
    if uid, err := userIDFromBearer(c); err == nil {
        ctxA, cancelA := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancelA()
        ok, err := Can(ctxA, uid, "policy:write", in.Where.OrgPrefix)
        if err != nil { return c.Status(500).SendString("authz error") }
        if !ok { return c.Status(403).SendString("forbidden: policy:write not allowed at this path") }
    } else {
        return err
    }

    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

	if _, err := policyCol().InsertOne(ctx, in); err != nil {
		log.Println("insert policy error:", err)
		return c.Status(500).SendString("insert failed")
	}
	return c.Status(201).JSON(in)
}

// PUT /policies  (idempotent upsert by (position_key, where.org_prefix, scope))
// @Summary      Upsert policy
// @Description  Upsert (create or update) a policy by position_key, org_prefix, and scope
// @Tags         policies
// @Accept       json
// @Produce      json
// @Param        Policy  body      Policy  true  "Policy info"
// @Success      200  {object}  Policy
// @Router       /policies [put]
func UpsertPolicy(c *fiber.Ctx) error {
    var in Policy
    if err := c.BodyParser(&in); err != nil {
        return c.Status(400).SendString("invalid body")
    }
	in.Where.OrgPrefix = strings.TrimSpace(in.Where.OrgPrefix)
	in.PositionKey = strings.TrimSpace(in.PositionKey)
	if in.Where.OrgPrefix == "" || in.PositionKey == "" {
		return c.Status(400).SendString("org_prefix & position_key required")
	}
	if in.Scope == "" {
		in.Scope = "exact"
	}
	if in.Effect == "" {
		in.Effect = "allow"
	}
	if !in.Enabled {
		in.Enabled = true
	}
    if in.CreatedAt.IsZero() {
        in.CreatedAt = time.Now()
    }

    // authz: require policy:write at where.org_prefix
    if uid, err := userIDFromBearer(c); err == nil {
        ctxA, cancelA := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancelA()
        ok, err := Can(ctxA, uid, "policy:write", in.Where.OrgPrefix)
        if err != nil { return c.Status(500).SendString("authz error") }
        if !ok { return c.Status(403).SendString("forbidden: policy:write not allowed at this path") }
    } else {
        return err
    }

    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

	filter := bson.M{
		"position_key":      in.PositionKey,
		"where.org_prefix":  in.Where.OrgPrefix,
		"scope":             in.Scope,
	}
	opts := options.FindOneAndUpdate().SetUpsert(true).SetReturnDocument(options.After)
	res := policyCol().FindOneAndUpdate(ctx, filter, bson.M{"$set": in}, opts)
	if res.Err() != nil && !errors.Is(res.Err(), mongo.ErrNoDocuments) {
		return c.Status(500).SendString("DB error")
	}
	var out Policy
	_ = res.Decode(&out)
	return c.JSON(out)
}

// DELETE /policies?org_prefix=/faculty/&position_key=head
// @Summary      Delete policy
// @Description  Delete policies by org_prefix and optional position_key
// @Tags         policies
// @Param        org_prefix    query     string  true  "Organization prefix"
// @Param        position_key  query     string  false "Position key"
// @Success      204  "No Content"
// @Router       /policies [delete]
func DeletePolicy(c *fiber.Ctx) error {
    orgPrefix := strings.TrimSpace(c.Query("org_prefix"))
    pos := strings.TrimSpace(c.Query("position_key"))
    if orgPrefix == "" {
        return c.Status(400).SendString("org_prefix required")
    }

    // authz: require policy:write at orgPrefix
    if uid, err := userIDFromBearer(c); err == nil {
        ctxA, cancelA := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancelA()
        ok, err := Can(ctxA, uid, "policy:write", orgPrefix)
        if err != nil { return c.Status(500).SendString("authz error") }
        if !ok { return c.Status(403).SendString("forbidden: policy:write not allowed at this path") }
    } else {
        return err
    }

    filter := bson.M{"where.org_prefix": orgPrefix}
	if pos != "" {
		filter["position_key"] = pos
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	res, err := policyCol().DeleteMany(ctx, filter)
	if err != nil {
		return c.Status(500).SendString("DB error")
	}
	if res.DeletedCount == 0 {
		return c.SendStatus(404)
	}
	return c.SendStatus(204)
}

func RegisterPolicyRoutes(router fiber.Router) {
	router.Get("/policies", ListPolicies)
	router.Post("/policies", CreatePolicy)
	router.Put("/policies", UpsertPolicy)
	router.Delete("/policies", DeletePolicy)

	// abilities
	router.Get("/abilities", GetAbilities)        // per org_path
	router.Get("/abilities/where", WhereAbilities) // where can I do action
}
