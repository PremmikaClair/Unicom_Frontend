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

// ---------- Models (inline to make this file drop-in) ----------
type Position struct {
	Key         string            `bson:"key" json:"key"`                                 // stable id (e.g., "head")
	Display     map[string]string `bson:"display" json:"display"`                         // { "en": "Head" }
	Rank        int               `bson:"rank" json:"rank"`                               // sort order

	Scope struct {
		OrgPath string `bson:"org_path" json:"org_path"`                                   // where defined ("/" for global)
		Inherit bool   `bson:"inherit" json:"inherit"`                                     // usable by descendants?
	} `bson:"scope" json:"scope"`

	Constraints struct {
		ExclusivePerOrg bool  `bson:"exclusive_per_org" json:"exclusive_per_org"`          // 1 per org?
		MaxSlots        *int  `bson:"max_slots,omitempty" json:"max_slots,omitempty"`      // capacity (nil = unlimited)
		TermDays        *int  `bson:"term_days,omitempty" json:"term_days,omitempty"`      // optional expiry window
	} `bson:"constraints" json:"constraints"`

	Status    string    `bson:"status" json:"status"`                                     // "active" | "deprecated"
	CreatedAt time.Time `bson:"created_at,omitempty" json:"created_at,omitempty"`
	UpdatedAt time.Time `bson:"updated_at,omitempty" json:"updated_at,omitempty"`
}

// ---------- Helpers ----------
func posCol() *mongo.Collection { return config.DB.Collection("positions") }

// ---------- Handlers ----------

// @Summary List positions
// @Tags positions
// @Produce json
// @Success 200 {array} Position
// @Router /positions [get]
func GetPositions(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cur, err := posCol().Find(ctx, bson.D{})
	if err != nil {
		log.Println("positions find error:", err)
		return c.Status(500).SendString("DB error")
	}
	defer cur.Close(ctx)

	var items []Position
	if err := cur.All(ctx, &items); err != nil {
		log.Println("positions decode error:", err)
		return c.Status(500).SendString("Decode error")
	}
	if items == nil { items = []Position{} }
	return c.JSON(items)
}

// @Summary Get a position by key
// @Tags positions
// @Produce json
// @Param key path string true "Position key"
// @Success 200 {object} Position
// @Router /positions/{key} [get]
func GetPositionByKey(c *fiber.Ctx) error {
	key := strings.TrimSpace(c.Params("key"))
	if key == "" {
		return c.Status(400).SendString("invalid key")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var out Position
	err := posCol().FindOne(ctx, bson.M{"key": key}).Decode(&out)
	if errors.Is(err, mongo.ErrNoDocuments) { return c.SendStatus(404) }
	if err != nil {
		log.Println("positions FindOne error:", err)
		return c.Status(500).SendString("DB error")
	}
	return c.JSON(out)
}

// @Summary Create position
// @Tags positions
// @Accept json
// @Produce json
// @Param position body Position true "Position"
// @Success 201 {object} Position
// @Router /positions [post]
func CreatePosition(c *fiber.Ctx) error {
    var in Position
    if err := c.BodyParser(&in); err != nil {
        return c.Status(400).SendString("invalid body")
    }
	in.Key = strings.TrimSpace(in.Key)
	if in.Key == "" {
		return c.Status(400).SendString("key is required")
	}
	if in.Display == nil { in.Display = map[string]string{"en": in.Key} }
	if in.Status == "" { in.Status = "active" }
    in.CreatedAt = time.Now()
    in.UpdatedAt = in.CreatedAt

    // authz: require position:create at scope.org_path (default "/")
    ownerPath := in.Scope.OrgPath
    if strings.TrimSpace(ownerPath) == "" { ownerPath = "/" }
    if uid, err := userIDFromBearer(c); err == nil {
        ctxA, cancelA := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancelA()
        ok, err := Can(ctxA, uid, "position:create", ownerPath)
        if err != nil { return c.Status(500).SendString("authz error") }
        if !ok { return c.Status(403).SendString("forbidden: position:create not allowed at this path") }
    } else {
        return err
    }

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// unique by key
	cnt, err := posCol().CountDocuments(ctx, bson.M{"key": in.Key})
	if err != nil { return c.Status(500).SendString("DB error") }
	if cnt > 0 { return c.Status(409).SendString("position already exists") }

	if _, err := posCol().InsertOne(ctx, in); err != nil {
		log.Println("insert position error:", err)
		return c.Status(500).SendString("insert failed")
	}
	return c.Status(201).JSON(in)
}

// @Summary Update position
// @Tags positions
// @Accept json
// @Produce json
// @Param key path string true "Position key"
// @Param position body Position true "Position (partial)"
// @Success 200 {object} Position
// @Router /positions/{key} [put]
func UpdatePosition(c *fiber.Ctx) error {
	key := strings.TrimSpace(c.Params("key"))
	if key == "" { return c.Status(400).SendString("invalid key") }

	var patch Position
	if err := c.BodyParser(&patch); err != nil { return c.Status(400).SendString("invalid body") }

	set := bson.M{}
	if patch.Display != nil && len(patch.Display) > 0 { set["display"] = patch.Display }
	if patch.Rank != 0 { set["rank"] = patch.Rank }
	if patch.Scope.OrgPath != "" { set["scope.org_path"] = patch.Scope.OrgPath }
	if patch.Scope.Inherit { set["scope.inherit"] = patch.Scope.Inherit } // false is valid; omit means "no change"
	if patch.Constraints.ExclusivePerOrg { set["constraints.exclusive_per_org"] = patch.Constraints.ExclusivePerOrg }
	if patch.Constraints.MaxSlots != nil { set["constraints.max_slots"] = patch.Constraints.MaxSlots }
	if patch.Constraints.TermDays != nil { set["constraints.term_days"] = patch.Constraints.TermDays }
	if patch.Status != "" { set["status"] = patch.Status }
	if len(set) == 0 { return c.Status(400).SendString("no fields to update") }
    set["updated_at"] = time.Now()

    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

	opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
	res := posCol().FindOneAndUpdate(ctx, bson.M{"key": key}, bson.M{"$set": set}, opts)
	if res.Err() != nil {
		if errors.Is(res.Err(), mongo.ErrNoDocuments) { return c.SendStatus(404) }
		log.Println("update position error:", res.Err())
		return c.Status(500).SendString("DB error")
	}
	var out Position
	if err := res.Decode(&out); err != nil { return c.Status(500).SendString("decode error") }
	return c.JSON(out)
}

// @Summary Deprecate position (soft delete)
// @Tags positions
// @Produce json
// @Param key path string true "Position key"
// @Success 204 "No Content"
// @Router /positions/{key} [delete]
func DeprecatePosition(c *fiber.Ctx) error {
	key := strings.TrimSpace(c.Params("key"))
	if key == "" { return c.Status(400).SendString("invalid key") }

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	res, err := posCol().UpdateOne(ctx, bson.M{"key": key}, bson.M{"$set": bson.M{"status": "deprecated", "updated_at": time.Now()}})
	if err != nil { log.Println("deprecate position error:", err); return c.Status(500).SendString("DB error") }
	if res.MatchedCount == 0 { return c.SendStatus(404) }
	return c.SendStatus(204)
}

// Matches your router style:
func RegisterPositionRoutes(router fiber.Router) {
	router.Get("/positions", GetPositions)
	router.Get("/positions/:key", GetPositionByKey)
	router.Post("/positions", CreatePosition)
	router.Put("/positions/:key", UpdatePosition)
	router.Delete("/positions/:key", DeprecatePosition)
}
