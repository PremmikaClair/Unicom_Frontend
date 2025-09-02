package api

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"github.com/pllus/main-fiber/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ====== Paged Response ======

type PagedUsersResponse struct {
	Items      any    `json:"items"` // []models.User or []models.UserWithRoleDetails
	NextCursor string `json:"nextCursor,omitempty"`
}

// ====== Helpers ======

func usersColl() *mongo.Collection { return config.DB.Collection("users") }
func rolesColl() *mongo.Collection { return config.DB.Collection("roles") }

// DB context
func dbCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Second)
}

// keyset cursor uses numeric "id"
type cursorPayload struct {
	LastID int `json:"id"`
}

func encodeCursor(lastID int) (string, error) {
	b, err := json.Marshal(cursorPayload{LastID: lastID})
	if err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func decodeCursor(c string) (int, bool) {
	if c == "" {
		return 0, false
	}
	b, err := base64.RawURLEncoding.DecodeString(c)
	if err != nil {
		return 0, false
	}
	var p cursorPayload
	if err := json.Unmarshal(b, &p); err != nil {
		return 0, false
	}
	return p.LastID, true
}

func parseInclude(raw string) (withLookup bool) {
	if raw == "" {
		return false
	}
	for _, p := range strings.Split(raw, ",") {
		p = strings.TrimSpace(strings.ToLower(p))
		if p == "roles" || p == "permissions" {
			return true
		}
	}
	return false
}

func parseLimit(q string, def, max int) int {
	if q == "" {
		return def
	}
	n, err := strconv.Atoi(q)
	if err != nil || n <= 0 {
		return def
	}
	if n > max {
		return max
	}
	return n
}

// ====== Handlers ======

// @Summary Get users with search, filters, pagination
// @Tags users
// @Produce json
// @Param q query string false "Search by name/email/student_id"
// @Param role query string false "Filter by role name"
// @Param limit query int false "Page size (default 20, max 100)"
// @Param cursor query string false "Keyset cursor (base64)"
// @Param include query string false "roles,permissions to expand roleDetails"
// @Success 200 {object} PagedUsersResponse
// @Router /users [get]
func GetUsers(c *fiber.Ctx) error {
	col := usersColl()

	q := strings.TrimSpace(c.Query("q"))
	role := strings.TrimSpace(c.Query("role"))
	limit := parseLimit(c.Query("limit"), 20, 100)
	cursor := c.Query("cursor")
	include := parseInclude(c.Query("include"))

	match := bson.M{}
	var and []bson.M

	// search across firstName, lastName, email, student_id
	if q != "" {
		reg := bson.M{"$regex": q, "$options": "i"}
		and = append(and, bson.M{"$or": []bson.M{
			{"firstName": reg},
			{"lastName": reg},
			{"email": reg},
			{"student_id": reg},
		}})
	}

	// filter by role
	if role != "" {
		and = append(and, bson.M{"roles": role})
	}

	// keyset pagination: id > lastID
	if lastID, ok := decodeCursor(cursor); ok {
		and = append(and, bson.M{"id": bson.M{"$gt": lastID}})
	}

	if len(and) > 0 {
		match["$and"] = and
	}

	pipeline := mongo.Pipeline{
		bson.D{{Key: "$match", Value: match}},
		bson.D{{Key: "$sort", Value: bson.D{{Key: "id", Value: 1}}}},
	}

	if include {
		pipeline = append(pipeline,
			bson.D{{Key: "$lookup", Value: bson.M{
				"from":         rolesColl().Name(),
				"localField":   "roles",
				"foreignField": "name",
				"as":           "roleDetails",
			}}},
		)
	}

	pipeline = append(pipeline, bson.D{{Key: "$limit", Value: limit + 1}})

	ctx, cancel := dbCtx()
	defer cancel()

	cur, err := col.Aggregate(ctx, pipeline)
	if err != nil {
		log.Println("Aggregate error:", err)
		return c.Status(500).SendString("DB error")
	}
	defer cur.Close(ctx)

	if include {
		var docs []models.UserWithRoleDetails
		if err := cur.All(ctx, &docs); err != nil {
			log.Println("Cursor decode error:", err)
			return c.Status(500).SendString("Decode error")
		}
		next := ""
		if len(docs) > limit {
			last := docs[limit-1]
			if nc, err := encodeCursor(last.SeqID); err == nil { // ID is numeric app id
				next = nc
			}
			docs = docs[:limit]
		}
		return c.JSON(PagedUsersResponse{Items: docs, NextCursor: next})
	}

	var users []models.User
	if err := cur.All(ctx, &users); err != nil {
		log.Println("Cursor decode error:", err)
		return c.Status(500).SendString("Decode error")
	}
	next := ""
	if len(users) > limit {
		last := users[limit-1]
		if nc, err := encodeCursor(last.SeqID); err == nil {
			next = nc
		}
		users = users[:limit]
	}
	return c.JSON(PagedUsersResponse{Items: users, NextCursor: next})
}

// @Summary Get a single user by numeric app id
// @Tags users
// @Produce json
// @Param id path int true "User numeric id"
// @Param include query string false "roles,permissions to expand roleDetails"
// @Success 200 {object} models.User
// @Router /users/{id} [get]
func GetUserByID(c *fiber.Ctx) error {
	userID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(400).SendString("Invalid id")
	}
	include := parseInclude(c.Query("include"))

	col := usersColl()
	ctx, cancel := dbCtx()
	defer cancel()

	if include {
		pipeline := mongo.Pipeline{
			bson.D{{Key: "$match", Value: bson.M{"id": userID}}},
			bson.D{{Key: "$limit", Value: 1}},
			bson.D{{Key: "$lookup", Value: bson.M{
				"from":         rolesColl().Name(),
				"localField":   "roles",
				"foreignField": "name",
				"as":           "roleDetails",
			}}},
		}
		cur, err := col.Aggregate(ctx, pipeline)
		if err != nil {
			log.Println("Aggregate error:", err)
			return c.Status(500).SendString("DB error")
		}
		defer cur.Close(ctx)

		if cur.Next(ctx) {
			var out models.UserWithRoleDetails
			if err := cur.Decode(&out); err != nil {
				return c.Status(500).SendString("Decode error")
			}
			return c.JSON(out)
		}
		return c.SendStatus(404)
	}

	var u models.User
	err = col.FindOne(ctx, bson.M{"id": userID}).Decode(&u)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return c.SendStatus(404)
	}
	if err != nil {
		log.Println("FindOne error:", err)
		return c.Status(500).SendString("DB error")
	}
	return c.JSON(u)
}

// @Summary Create a new user
// @Tags users
// @Accept json
// @Produce json
// @Param user body models.User true "User"
// @Success 201 {object} models.User
// @Router /users [post]
func CreateUser(c *fiber.Ctx) error {
	var newUser models.User
	if err := c.BodyParser(&newUser); err != nil {
		log.Println("Body parse error:", err)
		return c.Status(fiber.StatusBadRequest).SendString("Invalid request")
	}

	if newUser.SeqID == 0 {
		return c.Status(400).SendString("id is required (numeric)")
	}
	if strings.TrimSpace(newUser.Email) == "" {
		return c.Status(400).SendString("email is required")
	}

	col := usersColl()
	ctx, cancel := dbCtx()
	defer cancel()

	// unique on id
	count, err := col.CountDocuments(ctx, bson.M{"id": newUser.ID})
	if err != nil {
		return c.Status(500).SendString("DB error")
	}
	if count > 0 {
		return c.Status(409).SendString("User with this id already exists")
	}

	_, err = col.InsertOne(ctx, newUser)
	if err != nil {
		log.Println("Insert error:", err)
		return c.Status(500).SendString("Failed to insert user")
	}

	return c.Status(fiber.StatusCreated).JSON(newUser)
}

// @Summary Update an existing user by numeric id
// @Tags users
// @Accept json
// @Produce json
// @Param id path int true "User numeric id"
// @Param user body models.User true "User partial or full"
// @Success 200 {object} models.User
// @Router /users/{id} [put]
func UpdateUser(c *fiber.Ctx) error {
	userID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(400).SendString("Invalid id")
	}

	var patch models.User
	if err := c.BodyParser(&patch); err != nil {
		return c.Status(400).SendString("Invalid body")
	}

	update := bson.M{}
	if patch.FirstName != "" {
		update["firstName"] = patch.FirstName
	}
	if patch.LastName != "" {
		update["lastName"] = patch.LastName
	}
	if patch.ThaiPrefix != "" {
		update["thaiprefix"] = patch.ThaiPrefix
	}
	if patch.Gender != "" {
		update["gender"] = patch.Gender
	}
	if patch.TypePerson != "" {
		update["type_person"] = patch.TypePerson
	}
	if patch.StudentID != "" {
		update["student_id"] = patch.StudentID
	}
	if patch.AdvisorID != "" {
		update["advisor_id"] = patch.AdvisorID
	}
	if patch.Email != "" {
		update["email"] = patch.Email
	}
	if patch.Roles != nil {
		update["roles"] = patch.Roles
	}

	if len(update) == 0 {
		return c.Status(400).SendString("No fields to update")
	}

	col := usersColl()
	ctx, cancel := dbCtx()
	defer cancel()

	opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
	res := col.FindOneAndUpdate(ctx,
		bson.M{"id": userID},
		bson.M{"$set": update},
		opts,
	)
	if res.Err() != nil {
		if errors.Is(res.Err(), mongo.ErrNoDocuments) {
			return c.SendStatus(404)
		}
		log.Println("FindOneAndUpdate error:", res.Err())
		return c.Status(500).SendString("DB error")
	}

	var updated models.User
	if err := res.Decode(&updated); err != nil {
		return c.Status(500).SendString("Decode error")
	}
	return c.JSON(updated)
}

// @Summary Delete a user by numeric id
// @Tags users
// @Produce json
// @Param id path int true "User numeric id"
// @Success 204 "No Content"
// @Router /users/{id} [delete]
func DeleteUser(c *fiber.Ctx) error {
	userID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(400).SendString("Invalid id")
	}

	col := usersColl()
	ctx, cancel := dbCtx()
	defer cancel()

	res, err := col.DeleteOne(ctx, bson.M{"id": userID})
	if err != nil {
		log.Println("DeleteOne error:", err)
		return c.Status(500).SendString("DB error")
	}
	if res.DeletedCount == 0 {
		return c.SendStatus(404)
	}
	return c.SendStatus(204)
}

// ===== Permissions (flattened & deduplicated) =====

type FlatPermission struct {
	Key      string `json:"key"`      // "resource:action" for frontend convenience
	Resource string `json:"resource"` // "user"
	Action   string `json:"action"`   // "read"
}

// GET /users/:id/permissions
func GetUserPermissions(c *fiber.Ctx) error {
	userID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
	return c.Status(400).SendString("invalid id")
	}

	ctx, cancel := dbCtx()
	defer cancel()

	// 1) Load user
	var u models.User
	if err := usersColl().FindOne(ctx, bson.M{"id": userID}).Decode(&u); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return c.SendStatus(404)
		}
		log.Println("FindOne error:", err)
		return c.Status(500).SendString("DB error")
	}
	if len(u.Roles) == 0 {
		return c.JSON([]FlatPermission{})
	}

	// 2) Load roles
	cur, err := rolesColl().Find(ctx, bson.M{"name": bson.M{"$in": u.Roles}})
	if err != nil {
		log.Println("Find roles error:", err)
		return c.Status(500).SendString("DB error")
	}
	defer cur.Close(ctx)

	// 3) Deduplicate
	uniq := map[string]FlatPermission{}

	for cur.Next(ctx) {
		var raw bson.M
		if err := cur.Decode(&raw); err != nil {
			log.Println("Role decode error:", err)
			return c.Status(500).SendString("Decode error")
		}

		permA, _ := raw["permissions"].(bson.A)
		for _, item := range permA {
			switch v := item.(type) {
			case string:
				res, act := splitResAct(v)
				if res == "" || act == "" {
					continue
				}
				key := res + ":" + act
				uniq[key] = FlatPermission{Key: key, Resource: res, Action: act}

			case bson.M:
				res := fmt.Sprint(v["resource"])
				act := fmt.Sprint(v["action"])
				if res == "" || act == "" {
					continue
				}
				key := res + ":" + act
				uniq[key] = FlatPermission{Key: key, Resource: res, Action: act}

			case bson.D:
				var res, act string
				for _, e := range v {
					switch e.Key {
					case "resource":
						res = fmt.Sprint(e.Value)
					case "action":
						act = fmt.Sprint(e.Value)
					}
				}
				if res != "" && act != "" {
					key := res + ":" + act
					uniq[key] = FlatPermission{Key: key, Resource: res, Action: act}
				}
			}
		}
	}

	// 4) Convert map → slice
	out := make([]FlatPermission, 0, len(uniq))
	for _, p := range uniq {
		out = append(out, p)
	}

	return c.JSON(out)
}

// helpers
func splitResAct(s string) (string, string) {
	parts := strings.SplitN(s, ":", 2)
	if len(parts) == 2 {
		return parts[0], parts[1]
	}
	return parts[0], ""
}

// RegisterUserRoutes registers user routes
func RegisterUserRoutes(router fiber.Router) {
	router.Get("/users", GetUsers)
	router.Get("/users/:id", GetUserByID)
	router.Post("/users", CreateUser)
	router.Put("/users/:id", UpdateUser)
	router.Delete("/users/:id", DeleteUser)
	router.Get("/users/:id/permissions", GetUserPermissions)
}