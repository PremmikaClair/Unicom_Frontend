package user

import (
	"context"
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// User represents the MongoDB user schema
type User struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	UserID    int                `bson:"id" json:"id"`
	FirstName string             `bson:"firstName" json:"firstName"`
	LastName  string             `bson:"lastName" json:"lastName"`
	Email     string             `bson:"email" json:"email"`
	Roles     []string           `bson:"roles" json:"roles"`
}

// GetUsers godoc
// @Summary Get all users
// @Tags users
// @Produce json
// @Success 200 {array} user.User
// @Router /users [get]
func GetUsers(c *fiber.Ctx) error {
	collection := config.DB.Collection("Users")

	cursor, err := collection.Find(context.Background(), bson.M{})
	if err != nil {
		log.Println("Find error:", err)
		return c.Status(500).SendString("DB error")
	}
	defer cursor.Close(context.Background())

	var users []User
	if err := cursor.All(context.Background(), &users); err != nil {
		log.Println("Cursor decode error:", err)
		return c.Status(500).SendString("Decode error")
	}

	return c.JSON(users)
}

// CreateUser godoc
// @Summary Create a new user
// @Tags users
// @Accept json
// @Produce json
// @Param user body user.User true "User"
// @Success 201 {object} user.User
// @Router /users [post]
func CreateUser(c *fiber.Ctx) error {
	var newUser User
	if err := c.BodyParser(&newUser); err != nil {
		log.Println("Body parse error:", err)
		return c.Status(fiber.StatusBadRequest).SendString("Invalid request")
	}

	collection := config.DB.Collection("Users")

	result, err := collection.InsertOne(context.Background(), newUser)
	if err != nil {
		log.Println("Insert error:", err)
		return c.Status(fiber.StatusInternalServerError).SendString("Failed to insert user")
	}

	newUser.ID = result.InsertedID.(primitive.ObjectID)
	return c.Status(fiber.StatusCreated).JSON(newUser)
}

// RegisterUserRoutes registers user routes
func RegisterUserRoutes(router fiber.Router) {
	router.Get("/users", GetUsers)
	router.Post("/users", CreateUser)
}