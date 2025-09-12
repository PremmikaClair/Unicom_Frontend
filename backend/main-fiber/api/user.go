// api/users.go
package api

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log"
	"strconv"
	"strings"
	"time"
	"github.com/pllus/main-fiber/config"
	"github.com/gofiber/fiber/v2"

	"github.com/pllus/main-fiber/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)


func usersCol() *mongo.Collection { return config.DB.Collection("users") }
func memCol() *mongo.Collection   { return config.DB.Collection("memberships") }

func orgCol() *mongo.Collection   { return config.DB.Collection("org_units") }

func ctx10() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Second)
}
// ====== Helpers ======
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

// ====== DTOs ======

type PagedUsersResponse struct {
	Items      any    `json:"items"` // []models.User
	NextCursor string `json:"nextCursor,omitempty"`
}

// ====== Handlers ======

// @Summary Get users with search + keyset pagination
// @Tags users
// @Produce json
// @Param q query string false "Search by name/email/student_id"
// @Param limit query int false "Page size (default 20, max 100)"
// @Param cursor query string false "Keyset cursor (base64)"
// @Success 200 {object} PagedUsersResponse
// @Router /users [get]
func GetUsers(c *fiber.Ctx) error {
	col := usersColl()

	q := strings.TrimSpace(c.Query("q"))
	limit := parseLimit(c.Query("limit"), 20, 100)
	cursor := c.Query("cursor")

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

	// keyset pagination: id > lastID
	if lastID, ok := decodeCursor(cursor); ok {
		and = append(and, bson.M{"id": bson.M{"$gt": lastID}})
	}
	if len(and) > 0 {
		match["$and"] = and
	}

	pipeline := mongo.Pipeline{
		bson.D{{Key: "$match", Value: match}},
		bson.D{{Key: "$sort", Value: bson.D{{Key: "id", Value: 1}}}}, // ascending for keyset
		bson.D{{Key: "$limit", Value: limit + 1}},                    // fetch one extra to build nextCursor
	}

	ctx, cancel := dbCtx()
	defer cancel()

	cur, err := col.Aggregate(ctx, pipeline)
	if err != nil {
		log.Println("users aggregate error:", err)
		return c.Status(500).SendString("DB error")
	}
	defer cur.Close(ctx)

	var users []models.User
	if err := cur.All(ctx, &users); err != nil {
		log.Println("users decode error:", err)
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
// @Success 200 {object} models.User
// @Router /users/{id} [get]
func GetUserByID(c *fiber.Ctx) error {
	userID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return c.Status(400).SendString("Invalid id")
	}

	col := usersColl()
	ctx, cancel := dbCtx()
	defer cancel()

	var u models.User
	err = col.FindOne(ctx, bson.M{"id": userID}).Decode(&u)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return c.SendStatus(404)
	}
	if err != nil {
		log.Println("users FindOne error:", err)
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
	var u models.User
	if err := c.BodyParser(&u); err != nil {
		log.Println("users body parse error:", err)
		return c.Status(fiber.StatusBadRequest).SendString("Invalid request")
	}

	// Basic validation
	if u.SeqID == 0 { // numeric app id stored in field "id"
		return c.Status(400).SendString("id is required (numeric)")
	}
	if strings.TrimSpace(u.Email) == "" {
		return c.Status(400).SendString("email is required")
	}

	col := usersColl()
	ctx, cancel := dbCtx()
	defer cancel()

	// unique on id and email
	if n, err := col.CountDocuments(ctx, bson.M{"id": u.SeqID}); err != nil {
		return c.Status(500).SendString("DB error")
	} else if n > 0 {
		return c.Status(409).SendString("User with this id already exists")
	}
	if n, err := col.CountDocuments(ctx, bson.M{"email": strings.ToLower(u.Email)}); err != nil {
		return c.Status(500).SendString("DB error")
	} else if n > 0 {
		return c.Status(409).SendString("User with this email already exists")
	}

	// normalize email on write
	u.Email = strings.ToLower(strings.TrimSpace(u.Email))

	if _, err := col.InsertOne(ctx, u); err != nil {
		log.Println("users insert error:", err)
		return c.Status(500).SendString("Failed to insert user")
	}
	return c.Status(fiber.StatusCreated).JSON(u)
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

	set := bson.M{}
	if s := strings.TrimSpace(patch.FirstName); s != "" {
		set["firstName"] = s
	}
	if s := strings.TrimSpace(patch.LastName); s != "" {
		set["lastName"] = s
	}
	if s := strings.TrimSpace(patch.ThaiPrefix); s != "" {
		set["thaiprefix"] = s
	}
	if s := strings.TrimSpace(patch.Gender); s != "" {
		set["gender"] = s
	}
	if s := strings.TrimSpace(patch.TypePerson); s != "" {
		set["type_person"] = s
	}
	if s := strings.TrimSpace(patch.StudentID); s != "" {
		set["student_id"] = s
	}
	if s := strings.TrimSpace(patch.AdvisorID); s != "" {
		set["advisor_id"] = s
	}
	if s := strings.TrimSpace(patch.Email); s != "" {
		set["email"] = strings.ToLower(s)
	}

	if len(set) == 0 {
		return c.Status(400).SendString("No fields to update")
	}

	col := usersColl()
	ctx, cancel := dbCtx()
	defer cancel()

	opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
	res := col.FindOneAndUpdate(ctx,
		bson.M{"id": userID},
		bson.M{"$set": set},
		opts,
	)
	if res.Err() != nil {
		if errors.Is(res.Err(), mongo.ErrNoDocuments) {
			return c.SendStatus(404)
		}
		log.Println("users update error:", res.Err())
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
		log.Println("users delete error:", err)
		return c.Status(500).SendString("DB error")
	}
	if res.DeletedCount == 0 {
		return c.SendStatus(404)
	}
	return c.SendStatus(204)
}


	
// Router registration
func RegisterUserRoutes(router fiber.Router) {
	router.Get("/users", GetUsers)
	router.Get("/users/:id", GetUserByID)
	router.Post("/users", CreateUser)
	router.Put("/users/:id", UpdateUser)
	router.Delete("/users/:id", DeleteUser)
}