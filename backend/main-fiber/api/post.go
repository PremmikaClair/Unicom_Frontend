// api/post.go
package api

import (
	"context"
	"errors"
	"strconv"
	"time"
	

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ---------- Model ----------

type Post struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"_id"`
	UID       string             `bson:"uid"           json:"uid"`
	Name      string             `bson:"name"          json:"name"`
	Username  string             `bson:"username"      json:"username"`
	Message   string             `bson:"message"       json:"message"`
	Timestamp time.Time          `bson:"timestamp"     json:"timestamp"`
	Likes     int                `bson:"likes"         json:"likes"`
	LikedBy   []string           `bson:"likedBy"       json:"likedBy"`
}

// ---------- Helpers ----------

func ctx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Second)
}

func toOID(id string) (primitive.ObjectID, error) {
	return primitive.ObjectIDFromHex(id)
}

func badRequest(c *fiber.Ctx, err error) error {
	return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
}

func notFound(c *fiber.Ctx) error {
	return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "not found"})
}

func serverError(c *fiber.Ctx, err error) error {
	return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
}

// ---------- Route registration ----------

// RegisterPostRoutes mounts routes at /api/posts
// Adjust config.GetDB() to however you expose *mongo.Database.
func RegisterPostRoutes(r fiber.Router) {
	col := config.DB.Collection("Posts")

	posts := r.Group("/posts")
	posts.Get("/", listPosts(col))
	posts.Get("/:id", getPost(col))
	posts.Post("/", createPost(col))
	posts.Put("/:id", updatePost(col))
	posts.Delete("/:id", deletePost(col))

	posts.Post("/:id/like", likePost(col))
	posts.Post("/:id/unlike", unlikePost(col))
}

// ---------- Handlers ----------

// GET /api/posts?page=&limit=
func listPosts(col *mongo.Collection) fiber.Handler {
	return func(c *fiber.Ctx) error {
		page, _ := strconv.Atoi(c.Query("page", "1"))
		limit, _ := strconv.Atoi(c.Query("limit", "20"))
		if page < 1 {
			page = 1
		}
		if limit < 1 || limit > 100 {
			limit = 20
		}

		skip := int64((page - 1) * limit)
		lim := int64(limit)

		ctxx, cancel := ctx()
		defer cancel()

		findOpts := options.Find().
			SetSort(bson.D{{Key: "timestamp", Value: -1}}).
			SetSkip(skip).
			SetLimit(lim)

		cur, err := col.Find(ctxx, bson.D{}, findOpts)
		if err != nil {
			return serverError(c, err)
		}
		defer cur.Close(ctxx)

		var posts []Post
		if err := cur.All(ctxx, &posts); err != nil {
			return serverError(c, err)
		}
		return c.JSON(posts)
	}
}

// GET /api/posts/:id
func getPost(col *mongo.Collection) fiber.Handler {
	return func(c *fiber.Ctx) error {
		oid, err := toOID(c.Params("id"))
		if err != nil {
			return badRequest(c, errors.New("invalid id"))
		}

		ctxx, cancel := ctx()
		defer cancel()

		var post Post
		err = col.FindOne(ctxx, bson.M{"_id": oid}).Decode(&post)
		if err == mongo.ErrNoDocuments {
			return notFound(c)
		}
		if err != nil {
			return serverError(c, err)
		}
		return c.JSON(post)
	}
}

type createPostDTO struct {
	UID      string `json:"uid"`
	Name     string `json:"name"`
	Username string `json:"username"`
	Message  string `json:"message"`
}

// POST /api/posts
func createPost(col *mongo.Collection) fiber.Handler {
	return func(c *fiber.Ctx) error {
		var dto createPostDTO
		if err := c.BodyParser(&dto); err != nil {
			return badRequest(c, err)
		}
		if dto.UID == "" || dto.Name == "" || dto.Username == "" || dto.Message == "" {
			return badRequest(c, errors.New("uid, name, username, message are required"))
		}

		doc := Post{
			UID:       dto.UID,
			Name:      dto.Name,
			Username:  dto.Username,
			Message:   dto.Message,
			Timestamp: time.Now().UTC(),
			Likes:     0,
			LikedBy:   []string{},
		}

		ctxx, cancel := ctx()
		defer cancel()

		res, err := col.InsertOne(ctxx, doc)
		if err != nil {
			return serverError(c, err)
		}

		doc.ID = res.InsertedID.(primitive.ObjectID)
		return c.Status(fiber.StatusCreated).JSON(doc)
	}
}

type updatePostDTO struct {
	Message *string   `json:"message,omitempty"`
	Likes   *int      `json:"likes,omitempty"`
	LikedBy *[]string `json:"likedBy,omitempty"`
}

// PUT /api/posts/:id
func updatePost(col *mongo.Collection) fiber.Handler {
	return func(c *fiber.Ctx) error {
		oid, err := toOID(c.Params("id"))
		if err != nil {
			return badRequest(c, errors.New("invalid id"))
		}

		var dto updatePostDTO
		if err := c.BodyParser(&dto); err != nil {
			return badRequest(c, err)
		}

		set := bson.M{}
		if dto.Message != nil {
			set["message"] = *dto.Message
		}
		if dto.Likes != nil {
			set["likes"] = *dto.Likes
		}
		if dto.LikedBy != nil {
			set["likedBy"] = *dto.LikedBy
		}
		if len(set) == 0 {
			return badRequest(c, errors.New("no fields to update"))
		}

		ctxx, cancel := ctx()
		defer cancel()

		after := options.After
		opts := options.FindOneAndUpdate().SetReturnDocument(after)

		var updated Post
		err = col.FindOneAndUpdate(
			ctxx,
			bson.M{"_id": oid},
			bson.M{"$set": set},
			opts,
		).Decode(&updated)

		if err == mongo.ErrNoDocuments {
			return notFound(c)
		}
		if err != nil {
			return serverError(c, err)
		}
		return c.JSON(updated)
	}
}

// DELETE /api/posts/:id
func deletePost(col *mongo.Collection) fiber.Handler {
	return func(c *fiber.Ctx) error {
		oid, err := toOID(c.Params("id"))
		if err != nil {
			return badRequest(c, errors.New("invalid id"))
		}

		ctxx, cancel := ctx()
		defer cancel()

		res, err := col.DeleteOne(ctxx, bson.M{"_id": oid})
		if err != nil {
			return serverError(c, err)
		}
		if res.DeletedCount == 0 {
			return notFound(c)
		}
		return c.SendStatus(fiber.StatusNoContent)
	}
}

type likeDTO struct {
	UserID string `json:"userId"`
}

// POST /api/posts/:id/like
func likePost(col *mongo.Collection) fiber.Handler {
	return func(c *fiber.Ctx) error {
		oid, err := toOID(c.Params("id"))
		if err != nil {
			return badRequest(c, errors.New("invalid id"))
		}

		var dto likeDTO
		if err := c.BodyParser(&dto); err != nil || dto.UserID == "" {
			return badRequest(c, errors.New("userId is required"))
		}

		ctxx, cancel := ctx()
		defer cancel()

		after := options.After
		opts := options.FindOneAndUpdate().SetReturnDocument(after)

		var updated Post
		err = col.FindOneAndUpdate(
			ctxx,
			bson.M{"_id": oid},
			bson.M{
				"$addToSet": bson.M{"likedBy": dto.UserID},
				"$inc":      bson.M{"likes": 1},
			},
			opts,
		).Decode(&updated)

		if err == mongo.ErrNoDocuments {
			return notFound(c)
		}
		if err != nil {
			return serverError(c, err)
		}
		return c.JSON(updated)
	}
}

// POST /api/posts/:id/unlike
func unlikePost(col *mongo.Collection) fiber.Handler {
	return func(c *fiber.Ctx) error {
		oid, err := toOID(c.Params("id"))
		if err != nil {
			return badRequest(c, errors.New("invalid id"))
		}

		var dto likeDTO
		if err := c.BodyParser(&dto); err != nil || dto.UserID == "" {
			return badRequest(c, errors.New("userId is required"))
		}

		ctxx, cancel := ctx()
		defer cancel()

		after := options.After
		opts := options.FindOneAndUpdate().SetReturnDocument(after)

		var updated Post
		err = col.FindOneAndUpdate(
			ctxx,
			bson.M{"_id": oid},
			bson.M{
				"$pull": bson.M{"likedBy": dto.UserID},
				"$inc":  bson.M{"likes": -1},
			},
			opts,
		).Decode(&updated)

		if err == mongo.ErrNoDocuments {
			return notFound(c)
		}
		if err != nil {
			return serverError(c, err)
		}

		// Guard: keep likes >= 0
		if updated.Likes < 0 {
			_, _ = col.UpdateByID(ctxx, oid, bson.M{"$set": bson.M{"likes": 0}})
			updated.Likes = 0
		}
		return c.JSON(updated)
	}
}