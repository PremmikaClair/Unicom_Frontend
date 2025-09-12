// api/memberships.go
package api

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func membershipCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Second)
}

func colUsers() *mongo.Collection       { return config.DB.Collection("users") }
func colMemberships() *mongo.Collection { return config.DB.Collection("memberships") }
func colOrgUnits() *mongo.Collection    { return config.DB.Collection("org_units") }
func colPositions() *mongo.Collection   { return config.DB.Collection("positions") }

// --------- Model ---------
type MembershipDoc struct {
	ID          primitive.ObjectID `bson:"_id,omitempty"    json:"_id"`
	UserID      primitive.ObjectID `bson:"user_id"          json:"user_id"`
	OrgPath     string             `bson:"org_path"         json:"org_path"`
	PositionKey string             `bson:"position_key"     json:"position_key"`
	Active      bool               `bson:"active"           json:"active"` // boolean flag
	JoinedAt    *time.Time         `bson:"joined_at,omitempty" json:"joined_at,omitempty"`
	EndedAt     *time.Time         `bson:"ended_at,omitempty"  json:"ended_at,omitempty"`
	CreatedAt   time.Time          `bson:"created_at"       json:"created_at"`
	UpdatedAt   time.Time          `bson:"updated_at"       json:"updated_at"`
}

// --------- Helpers ---------
func resolveUserOIDFlexible(ctx context.Context, ref string) (primitive.ObjectID, error) {
	ref = strings.TrimSpace(ref)
	if ref == "" {
		return primitive.NilObjectID, fiber.NewError(fiber.StatusBadRequest, "user_ref required")
	}
	if oid, err := primitive.ObjectIDFromHex(ref); err == nil {
		return oid, nil
	}
	if n, err := strconv.Atoi(ref); err == nil {
		var row struct{ ID primitive.ObjectID `bson:"_id"` }
		if err := colUsers().FindOne(ctx, bson.M{"id": n}).Decode(&row); err == nil && !row.ID.IsZero() {
			return row.ID, nil
		}
	}
	var row struct{ ID primitive.ObjectID `bson:"_id"` }
	if err := colUsers().FindOne(ctx, bson.M{"student_id": ref}).Decode(&row); err == nil && !row.ID.IsZero() {
		return row.ID, nil
	}
	return primitive.NilObjectID, fiber.NewError(fiber.StatusNotFound, "user not found")
}

func ensureOrg(ctx context.Context, path string) error {
	if strings.TrimSpace(path) == "" {
		return fiber.NewError(fiber.StatusBadRequest, "org_path required")
	}
	if err := colOrgUnits().FindOne(ctx, bson.M{"path": path}).Err(); errors.Is(err, mongo.ErrNoDocuments) {
		return fiber.NewError(fiber.StatusBadRequest, "org_path not found")
	} else if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	return nil
}
func ensurePosition(ctx context.Context, key string) error {
	if strings.TrimSpace(key) == "" {
		return fiber.NewError(fiber.StatusBadRequest, "position_key required")
	}
	if err := colPositions().FindOne(ctx, bson.M{"key": key}).Err(); errors.Is(err, mongo.ErrNoDocuments) {
		return fiber.NewError(fiber.StatusBadRequest, "position not found")
	} else if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	return nil
}

// --------- DTOs ---------
type CreateMembershipReq struct {
	UserRef     string     `json:"user_ref"`     // _id hex OR numeric id OR student_id
	OrgPath     string     `json:"org_path"`     // "/club/cpsk"
	PositionKey string     `json:"position_key"` // "head", "member", ...
	JoinedAt    *time.Time `json:"joined_at,omitempty"`
}

type UpdateMembershipReq struct {
	PositionKey *string    `json:"position_key,omitempty"`
	Active      *bool      `json:"active,omitempty"`   // boolean now
	EndedAt     *time.Time `json:"ended_at,omitempty"`
}

// --------- Handlers ---------

// POST /api/memberships
func CreateMembership(c *fiber.Ctx) error {
    var in CreateMembershipReq
    if err := c.BodyParser(&in); err != nil {
        return fiber.NewError(fiber.StatusBadRequest, "invalid body")
    }
    // authorization: actor must have membership:assign at org_path
    actorID, err := userIDFromBearer(c)
    if err != nil { return err }
    {
        ctx, cancel := membershipCtx(); defer cancel()
        ok, err := Can(ctx, actorID, "membership:assign", in.OrgPath)
        if err != nil { return fiber.NewError(fiber.StatusInternalServerError, "authz error") }
        if !ok { return fiber.NewError(fiber.StatusForbidden, "not allowed to assign membership at this path") }
    }
    ctx, cancel := membershipCtx()
    defer cancel()

	uid, err := resolveUserOIDFlexible(ctx, in.UserRef)
	if err != nil { return err }
	if err := ensureOrg(ctx, in.OrgPath); err != nil { return err }
	if err := ensurePosition(ctx, in.PositionKey); err != nil { return err }

	// prevent duplicate active membership
	exists, err := colMemberships().CountDocuments(ctx, bson.M{
		"user_id":      uid,
		"org_path":     in.OrgPath,
		"position_key": in.PositionKey,
		"active":       true,
	})
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
    if exists > 0 {
        return fiber.NewError(fiber.StatusConflict, "membership already exists")
    }

    // revive-if-inactive: if an inactive row exists for same triple, reactivate it
    var inactive MembershipDoc
    err = colMemberships().FindOne(ctx, bson.M{
        "user_id": uid,
        "org_path": in.OrgPath,
        "position_key": in.PositionKey,
        "active": false,
    }).Decode(&inactive)
    if err == nil && !inactive.ID.IsZero() {
        now := time.Now().UTC()
        after := options.After
        opts := options.FindOneAndUpdate().SetReturnDocument(after)
        var out MembershipDoc
        if err := colMemberships().FindOneAndUpdate(ctx, bson.M{"_id": inactive.ID}, bson.M{"$set": bson.M{
            "active": true,
            "ended_at": nil,
            "updated_at": now,
        }}, opts).Decode(&out); err == nil {
            return c.Status(fiber.StatusOK).JSON(out)
        }
        // fallthrough to insert if update fails
    }

	now := time.Now().UTC()
	doc := MembershipDoc{
		UserID:      uid,
		OrgPath:     in.OrgPath,
		PositionKey: in.PositionKey,
		Active:      true,
		JoinedAt:    in.JoinedAt,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	res, err := colMemberships().InsertOne(ctx, doc)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "insert failed")
	}
	doc.ID = res.InsertedID.(primitive.ObjectID)
	return c.Status(fiber.StatusCreated).JSON(doc)
}

// GET /api/memberships
func ListMemberships(c *fiber.Ctx) error {
	filter := bson.M{}

	if u := strings.TrimSpace(c.Query("user")); u != "" {
		ctx, cancel := membershipCtx()
		defer cancel()
		oid, err := resolveUserOIDFlexible(ctx, u)
		if err != nil { return err }
		filter["user_id"] = oid
	}
	if p := strings.TrimSpace(c.Query("org_path")); p != "" {
		filter["org_path"] = p
	}
	if k := strings.TrimSpace(c.Query("position_key")); k != "" {
		filter["position_key"] = k
	}

	// active query param: true | false | all (default: true)
	switch strings.ToLower(strings.TrimSpace(c.Query("active", "true"))) {
	case "false":
		filter["active"] = false
	case "all":
		// no filter
	default:
		filter["active"] = true
	}

	ctx, cancel := membershipCtx()
	defer cancel()

	cur, err := colMemberships().Find(ctx, filter)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	defer cur.Close(ctx)

	var items []MembershipDoc
	if err := cur.All(ctx, &items); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "decode error")
	}
	if items == nil {
		items = []MembershipDoc{}
	}
	return c.JSON(items)
}

// GET /api/memberships/:id
func GetMembership(c *fiber.Ctx) error {
	id := strings.TrimSpace(c.Params("id"))
	oid, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "bad id")
	}

	ctx, cancel := membershipCtx()
	defer cancel()

	var doc MembershipDoc
	if err := colMemberships().FindOne(ctx, bson.M{"_id": oid}).Decode(&doc); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return c.SendStatus(fiber.StatusNotFound)
		}
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	return c.JSON(doc)
}

// PATCH /api/memberships/:id
func UpdateMembership(c *fiber.Ctx) error {
    id := strings.TrimSpace(c.Params("id"))
    oid, err := primitive.ObjectIDFromHex(id)
    if err != nil {
        return fiber.NewError(fiber.StatusBadRequest, "bad id")
    }
    // fetch current to enforce authz on its org_path
    ctx, cancel := membershipCtx()
    defer cancel()
    var current MembershipDoc
    if err := colMemberships().FindOne(ctx, bson.M{"_id": oid}).Decode(&current); err != nil {
        if errors.Is(err, mongo.ErrNoDocuments) { return c.SendStatus(fiber.StatusNotFound) }
        return fiber.NewError(fiber.StatusInternalServerError, "DB error")
    }

    var in UpdateMembershipReq
    if err := c.BodyParser(&in); err != nil {
        return fiber.NewError(fiber.StatusBadRequest, "invalid body")
    }

    // authorization: actor must have membership:revoke at the membership's org_path
    actorID, err := userIDFromBearer(c)
    if err != nil { return err }
    {
        ctxX, cancel := membershipCtx(); defer cancel()
        ok, err := Can(ctxX, actorID, "membership:revoke", current.OrgPath)
        if err != nil { return fiber.NewError(fiber.StatusInternalServerError, "authz error") }
        if !ok { return fiber.NewError(fiber.StatusForbidden, "not allowed to modify membership at this path") }
    }

    set := bson.M{"updated_at": time.Now().UTC()}
    if in.PositionKey != nil && strings.TrimSpace(*in.PositionKey) != "" {
        set["position_key"] = strings.TrimSpace(*in.PositionKey)
    }
	if in.Active != nil {
		set["active"] = *in.Active
		// if deactivating and ended_at not supplied, set it now
		if !*in.Active && in.EndedAt == nil {
			now := time.Now().UTC()
			set["ended_at"] = now
		}
	}
	if in.EndedAt != nil {
		set["ended_at"] = *in.EndedAt
	}
	if len(set) == 1 { // only updated_at present
		return fiber.NewError(fiber.StatusBadRequest, "no fields to update")
	}

    opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
    var out MembershipDoc
    err = colMemberships().FindOneAndUpdate(ctx, bson.M{"_id": oid}, bson.M{"$set": set}, opts).Decode(&out)
    if errors.Is(err, mongo.ErrNoDocuments) {
        return c.SendStatus(fiber.StatusNotFound)
	}
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "update failed")
	}
	return c.JSON(out)
}

// DELETE /api/memberships/:id
func DeleteMembership(c *fiber.Ctx) error {
	id := strings.TrimSpace(c.Params("id"))
	oid, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "bad id")
	}

	ctx, cancel := membershipCtx()
	defer cancel()

	res, err := colMemberships().DeleteOne(ctx, bson.M{"_id": oid})
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	if res.DeletedCount == 0 {
		return c.SendStatus(fiber.StatusNotFound)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func RegisterMembershipRoutes(r fiber.Router) {
    g := r.Group("/memberships")
    g.Get("/", ListMemberships)
    // Place static path BEFORE ":id" to avoid capturing it as an id
    g.Get("/users", ListMembershipsWithUsers)
    g.Get("/:id", GetMembership)
    g.Post("/", CreateMembership)
    g.Patch("/:id", UpdateMembership)
    g.Delete("/:id", DeleteMembership)
}

// GET /api/memberships/users?org_path=/club/cpsk&active=true
// Joins memberships with user mini profile for easier UI rendering.
func ListMembershipsWithUsers(c *fiber.Ctx) error {
    filter := bson.M{}
    if p := strings.TrimSpace(c.Query("org_path")); p != "" {
        filter["org_path"] = p
    }
    switch strings.ToLower(strings.TrimSpace(c.Query("active", "true"))) {
    case "false":
        filter["active"] = false
    case "all":
        // no filter
    default:
        // Only active rows. Accept legacy rows without explicit active flag
        // Include: active=true OR (active missing AND (status='active' OR status missing))
        filter["$or"] = []bson.M{
            {"active": true},
            {"$and": []bson.M{
                {"active": bson.M{"$exists": false}},
                {"$or": []bson.M{{"status": "active"}, {"status": bson.M{"$exists": false}}}},
            }},
        }
    }

    ctx, cancel := membershipCtx();
    defer cancel()

    pipeline := mongo.Pipeline{
        bson.D{{Key: "$match", Value: filter}},
        bson.D{{Key: "$lookup", Value: bson.M{
            "from":         "users",
            "localField":   "user_id",
            "foreignField": "_id",
            "as":           "user",
        }}},
        bson.D{{Key: "$unwind", Value: bson.M{"path": "$user", "preserveNullAndEmptyArrays": true}}},
        bson.D{{Key: "$project", Value: bson.M{
            "_id":          1,
            "user_id":      1,
            "org_path":     1,
            "position_key": 1,
            "active":       1,
            "status":       1,
            "joined_at":    1,
            "user._id":     1,
            "user.id":      1,
            "user.firstName": 1,
            "user.lastName":  1,
            "user.email":     1,
            "user.student_id":1,
        }}},
    }

    cur, err := colMemberships().Aggregate(ctx, pipeline)
    if err != nil {
        return fiber.NewError(fiber.StatusInternalServerError, "DB error")
    }
    defer cur.Close(ctx)

    var out []bson.M
    if err := cur.All(ctx, &out); err != nil {
        return fiber.NewError(fiber.StatusInternalServerError, "decode error")
    }
    if out == nil { out = []bson.M{} }
    return c.JSON(out)
}
