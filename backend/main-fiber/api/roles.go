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

// ----- Model -----

type Role struct {
	ID          string   `json:"id" bson:"_id"`              // store _id as string
	Name        string   `json:"name" bson:"name"`
	Label       string   `json:"label" bson:"label"`
	Permissions []string `json:"permissions" bson:"permissions"`
}

// ----- Handlers -----

// @Summary List roles
// @Tags roles
// @Produce json
// @Success 200 {array} Role
// @Router /roles [get]
func GetRoles(c *fiber.Ctx) error {
	col := config.DB.Collection("roles")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cur, err := col.Find(ctx, bson.D{})
	if err != nil {
		log.Println("roles find error:", err)
		return c.Status(500).SendString("DB error")
	}
	defer cur.Close(ctx)

	var roles []Role
	if err := cur.All(ctx, &roles); err != nil {
		log.Println("roles decode error:", err)
		return c.Status(500).SendString("Decode error")
	}
	if roles == nil {
		roles = []Role{}
	}
	return c.JSON(roles)
}

// @Summary Get a role by id
// @Tags roles
// @Produce json
// @Param id path string true "Role id (usually same as name)"
// @Success 200 {object} Role
// @Router /roles/{id} [get]
func GetRoleByID(c *fiber.Ctx) error {
	id := strings.TrimSpace(c.Params("id"))
	if id == "" {
		return c.Status(400).SendString("invalid id")
	}
	col := config.DB.Collection("roles")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var role Role
	err := col.FindOne(ctx, bson.M{"_id": id}).Decode(&role)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return c.SendStatus(404)
	}
	if err != nil {
		log.Println("roles FindOne error:", err)
		return c.Status(500).SendString("DB error")
	}
	return c.JSON(role)
}

// @Summary Create role
// @Tags roles
// @Accept json
// @Produce json
// @Param role body Role true "Role"
// @Success 201 {object} Role
// @Router /roles [post]
func CreateRole(c *fiber.Ctx) error {
	var in Role
	if err := c.BodyParser(&in); err != nil {
		return c.Status(400).SendString("invalid body")
	}
	in.Name = strings.TrimSpace(in.Name)
	in.Label = strings.TrimSpace(in.Label)

	if in.Name == "" {
		return c.Status(400).SendString("name is required")
	}
	if in.ID == "" {
		in.ID = in.Name // keep id stable & simple
	}
	if in.Permissions == nil {
		in.Permissions = []string{}
	}

	col := config.DB.Collection("roles")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// uniqueness check
	cnt, err := col.CountDocuments(ctx, bson.M{"_id": in.ID})
	if err != nil {
		return c.Status(500).SendString("DB error")
	}
	if cnt > 0 {
		return c.Status(409).SendString("role already exists")
	}

	if _, err := col.InsertOne(ctx, in); err != nil {
		log.Println("insert role error:", err)
		return c.Status(500).SendString("insert failed")
	}
	return c.Status(201).JSON(in)
}

// @Summary Update role
// @Tags roles
// @Accept json
// @Produce json
// @Param id path string true "Role id"
// @Param role body Role true "Role (partial)"
// @Success 200 {object} Role
// @Router /roles/{id} [put]
func UpdateRole(c *fiber.Ctx) error {
	id := strings.TrimSpace(c.Params("id"))
	if id == "" {
		return c.Status(400).SendString("invalid id")
	}

	var patch Role
	if err := c.BodyParser(&patch); err != nil {
		return c.Status(400).SendString("invalid body")
	}

	set := bson.M{}
	if s := strings.TrimSpace(patch.Name); s != "" {
		set["name"] = s
	}
	if s := strings.TrimSpace(patch.Label); s != "" {
		set["label"] = s
	}
	if patch.Permissions != nil {
		set["permissions"] = patch.Permissions
	}
	if len(set) == 0 {
		return c.Status(400).SendString("no fields to update")
	}

	col := config.DB.Collection("roles")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
	res := col.FindOneAndUpdate(ctx, bson.M{"_id": id}, bson.M{"$set": set}, opts)
	if res.Err() != nil {
		if errors.Is(res.Err(), mongo.ErrNoDocuments) {
			return c.SendStatus(404)
		}
		log.Println("update role error:", res.Err())
		return c.Status(500).SendString("DB error")
	}

	var out Role
	if err := res.Decode(&out); err != nil {
		return c.Status(500).SendString("decode error")
	}
	return c.JSON(out)
}

// @Summary Delete role
// @Tags roles
// @Produce json
// @Param id path string true "Role id"
// @Success 204 "No Content"
// @Router /roles/{id} [delete]
func DeleteRole(c *fiber.Ctx) error {
	id := strings.TrimSpace(c.Params("id"))
	if id == "" {
		return c.Status(400).SendString("invalid id")
	}

	col := config.DB.Collection("roles")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	res, err := col.DeleteOne(ctx, bson.M{"_id": id})
	if err != nil {
		log.Println("delete role error:", err)
		return c.Status(500).SendString("DB error")
	}
	if res.DeletedCount == 0 {
		return c.SendStatus(404)
	}
	return c.SendStatus(204)
}

// Matches your user.go router style
func RegisterRoleRoutes(router fiber.Router) {
	router.Get("/roles", GetRoles)
	router.Get("/roles/:id", GetRoleByID)
	router.Post("/roles", CreateRole)
	router.Put("/roles/:id", UpdateRole)
	router.Delete("/roles/:id", DeleteRole)
}