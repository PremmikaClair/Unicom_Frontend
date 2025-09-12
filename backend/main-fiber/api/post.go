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

//
// ---------- Collections (use central config.DB) ----------
//
func postsColl() *mongo.Collection { return config.DB.Collection("posts") }
// NOTE: membershipsColl() is defined in your abilities file in the same package.
// We reuse it here without redefining.

//
// ---------- Models ----------
//

// Structured author identity (posting "in the name of")
type PostedAs struct {
	OrgPath     string `bson:"org_path,omitempty"     json:"org_path,omitempty"`
	PositionKey string `bson:"position_key,omitempty" json:"position_key,omitempty"`
	Label       string `bson:"label,omitempty"        json:"label,omitempty"` // e.g., "Head • SMO"
}

// Audience item for org visibility
type AudienceItem struct {
	OrgPath string `bson:"org_path" json:"org_path"`
	Scope   string `bson:"scope"    json:"scope"` // "exact" | "subtree"
}

// Visibility block
type Visibility struct {
	Access           string         `bson:"access,omitempty"            json:"access,omitempty"`            // "public" | "org" | "custom"
	Audience         []AudienceItem `bson:"audience,omitempty"          json:"audience,omitempty"`          // when Access="org"
	IncludePositions []string       `bson:"include_positions,omitempty" json:"include_positions,omitempty"`
	ExcludePositions []string       `bson:"exclude_positions,omitempty" json:"exclude_positions,omitempty"`
	AllowUserIDs     []string       `bson:"allow_user_ids,omitempty"    json:"allow_user_ids,omitempty"`
	DenyUserIDs      []string       `bson:"deny_user_ids,omitempty"     json:"deny_user_ids,omitempty"`
}

type Post struct {
	// Legacy fields (keep!)
	ID        primitive.ObjectID `bson:"_id,omitempty"   json:"_id"`
	UID       string             `bson:"uid"             json:"uid"`
	Name      string             `bson:"name"            json:"name"`
	Username  string             `bson:"username"        json:"username"`
	Message   string             `bson:"message"         json:"message"`
	Timestamp time.Time          `bson:"timestamp"       json:"timestamp"`
	Likes     int                `bson:"likes"           json:"likes"`
	LikedBy   []string           `bson:"likedBy"         json:"likedBy"`

	// NEW fields (optional)
	PostedAs     *PostedAs  `bson:"posted_as,omitempty"      json:"posted_as,omitempty"`
	Visibility   *Visibility `bson:"visibility,omitempty"     json:"visibility,omitempty"`
	OrgOfContent string     `bson:"org_of_content,omitempty" json:"org_of_content,omitempty"`
	Status       string     `bson:"status,omitempty"          json:"status,omitempty"` // "active" | "hidden" | "deleted"
	CreatedAt    *time.Time `bson:"created_at,omitempty"      json:"created_at,omitempty"`
	UpdatedAt    *time.Time `bson:"updated_at,omitempty"      json:"updated_at,omitempty"`
}

//
// ---------- DTOs ----------
//

type createPostDTO struct {
	UID      string `json:"uid"`
	Name     string `json:"name"`
	Username string `json:"username"`
	Message  string `json:"message"`

	// Optional
	PostedAs     *PostedAs  `json:"posted_as,omitempty"`
	Visibility   *Visibility `json:"visibility,omitempty"`
	OrgOfContent string     `json:"org_of_content,omitempty"`
	Status       string     `json:"status,omitempty"` // if omitted -> "active"
}

type updatePostDTO struct {
	// legacy (optional)
	Message *string   `json:"message,omitempty"`
	Likes   *int      `json:"likes,omitempty"`
	LikedBy *[]string `json:"likedBy,omitempty"`

	// NEW (optional)
	Status       *string     `json:"status,omitempty"` // "active" | "hidden" | "deleted"
	PostedAs     *PostedAs   `json:"posted_as,omitempty"`
	Visibility   *Visibility `json:"visibility,omitempty"`
	OrgOfContent *string     `json:"org_of_content,omitempty"`
}

//
// ---------- Generic helpers ----------
//

func ctx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Second)
}

func toOID(id string) (primitive.ObjectID, error) { return primitive.ObjectIDFromHex(id) }

func badRequest(c *fiber.Ctx, err error) error {
	return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
}
func notFound(c *fiber.Ctx) error {
	return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "not found"})
}
func serverError(c *fiber.Ctx, err error) error {
	return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
}

//
// ---------- Viewer resolution & memberships ----------
//

type userMini struct {
	ID        int                `bson:"id,omitempty"`
	OID       primitive.ObjectID `bson:"_id,omitempty"`
	Email     string             `bson:"email,omitempty"`
	StudentID string             `bson:"student_id,omitempty"`
}

func lookupUserByNumericID(id int) primitive.ObjectID {
	ctxx, cancel := ctx(); defer cancel()
	var u userMini
	_ = usersColl().FindOne(ctxx, bson.M{"id": id}).Decode(&u)
	return u.OID
}
func lookupUserByEmail(email string) primitive.ObjectID {
	ctxx, cancel := ctx(); defer cancel()
	var u userMini
	_ = usersColl().FindOne(ctxx, bson.M{"email": email}).Decode(&u)
	return u.OID
}
func lookupUserByStudentID(sid string) primitive.ObjectID {
	ctxx, cancel := ctx(); defer cancel()
	var u userMini
	_ = usersColl().FindOne(ctxx, bson.M{"student_id": sid}).Decode(&u)
	return u.OID
}

// Try to resolve viewer ObjectID from Locals / claims / Authorization
func viewerOID(c *fiber.Ctx) primitive.ObjectID {
	tryHex := func(s string) primitive.ObjectID {
		if oid, err := primitive.ObjectIDFromHex(s); err == nil { return oid }
		return primitive.NilObjectID
	}

	// 1) Common locals set by upstream auth
	if v := c.Locals("user_oid"); v != nil {
		if s, ok := v.(string); ok { if oid := tryHex(s); oid != primitive.NilObjectID { return oid } }
		if oid, ok := v.(primitive.ObjectID); ok { return oid }
	}
	if v := c.Locals("user_id"); v != nil {
		if s, ok := v.(string); ok { if oid := tryHex(s); oid != primitive.NilObjectID { return oid } }
		if oid, ok := v.(primitive.ObjectID); ok { return oid }
	}
	if v := c.Locals("uid"); v != nil {
		if s, ok := v.(string); ok { if oid := tryHex(s); oid != primitive.NilObjectID { return oid } }
	}

	// 2) Embedded user map
	if u := c.Locals("user"); u != nil {
		switch m := u.(type) {
		case map[string]any:
			if s, ok := m["_id"].(string); ok { if oid := tryHex(s); oid != primitive.NilObjectID { return oid } }
			if f, ok := m["id"].(float64); ok { if oid := lookupUserByNumericID(int(f)); oid != primitive.NilObjectID { return oid } }
			if i, ok := m["id"].(int); ok { if oid := lookupUserByNumericID(i); oid != primitive.NilObjectID { return oid } }
			if e, ok := m["email"].(string); ok { if oid := lookupUserByEmail(e); oid != primitive.NilObjectID { return oid } }
			if sid, ok := m["student_id"].(string); ok { if oid := lookupUserByStudentID(sid); oid != primitive.NilObjectID { return oid } }
		}
	}

	// 3) Other locals
	switch v := c.Locals("id").(type) {
	case int: if oid := lookupUserByNumericID(v); oid != primitive.NilObjectID { return oid }
	case int32: if oid := lookupUserByNumericID(int(v)); oid != primitive.NilObjectID { return oid }
	case int64: if oid := lookupUserByNumericID(int(v)); oid != primitive.NilObjectID { return oid }
	case float64: if oid := lookupUserByNumericID(int(v)); oid != primitive.NilObjectID { return oid }
	case string: if oid := tryHex(v); oid != primitive.NilObjectID { return oid }
	}
	if e, ok := c.Locals("email").(string); ok {
		if oid := lookupUserByEmail(e); oid != primitive.NilObjectID { return oid }
	}
	if sid, ok := c.Locals("student_id").(string); ok {
		if oid := lookupUserByStudentID(sid); oid != primitive.NilObjectID { return oid }
	}

	// 4) Fallback: parse bearer using your shared helper (same package)
	if oid, err := userIDFromBearer(c); err == nil {
		return oid
	}
	return primitive.NilObjectID
}

// Collect viewer org paths (exact + ancestors for subtree)
type membershipMini struct {
	OrgPath      string   `bson:"org_path"`
	OrgAncestors []string `bson:"org_ancestors,omitempty"`
}

func viewerOrgSets(userID primitive.ObjectID) (exact []string, subtree []string, err error) {
	if userID == primitive.NilObjectID {
		return nil, nil, nil // unauthenticated -> only public
	}
	ctxx, cancel := ctx(); defer cancel()

	cur, err := membershipsColl().Find(ctxx, bson.M{"user_id": userID})
	if err != nil { return nil, nil, err }
	defer cur.Close(ctxx)

	exactSet := map[string]struct{}{}
	subtreeSet := map[string]struct{}{}

	for cur.Next(ctxx) {
		var m membershipMini
		if err := cur.Decode(&m); err != nil { return nil, nil, err }
		if m.OrgPath != "" {
			exactSet[m.OrgPath] = struct{}{}
			subtreeSet[m.OrgPath] = struct{}{} // subtree includes self
		}
		for _, a := range m.OrgAncestors {
			subtreeSet[a] = struct{}{}
		}
	}
	for k := range exactSet { exact = append(exact, k) }
	for k := range subtreeSet { subtree = append(subtree, k) }
	return
}

//
// ---------- Visibility evaluation ----------
//

func isPostVisibleToViewer(p *Post, userOID primitive.ObjectID, exact, subtree []string) bool {
	if p.Status == "hidden" {
		return false
	}
	// No visibility block or public => visible
	if p.Visibility == nil || p.Visibility.Access == "" || p.Visibility.Access == "public" {
		return true
	}

	switch p.Visibility.Access {
	case "custom":
		if userOID == primitive.NilObjectID { return false }
		hex := userOID.Hex()
		for _, deny := range p.Visibility.DenyUserIDs { if deny == hex { return false } }
		for _, allow := range p.Visibility.AllowUserIDs { if allow == hex { return true } }
		return false

	case "org":
		if len(p.Visibility.Audience) == 0 { return false }
		exactSet := map[string]struct{}{}
		for _, s := range exact { exactSet[s] = struct{}{} }
		subtreeSet := map[string]struct{}{}
		for _, s := range subtree { subtreeSet[s] = struct{}{} }

		for _, a := range p.Visibility.Audience {
			switch a.Scope {
			case "exact":
				if _, ok := exactSet[a.OrgPath]; ok { return true }
			case "subtree":
				if _, ok := subtreeSet[a.OrgPath]; ok { return true }
			}
		}
		return false
	default:
		return false
	}
}

//
// ---------- Queries & Mutations ----------
//

// GET /api/posts?page=&limit[&all=true]
// @Summary      List posts
// @Description  List posts with pagination and visibility
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        page   query     int     false "Page number"
// @Param        limit  query     int     false "Page size"
// @Param        all    query     bool    false "Show all (moderation)"
// @Success      200    {array}   Post
// @Router       /api/posts [get]
func listPosts(c *fiber.Ctx) error {
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	if page < 1 { page = 1 }
	if limit < 1 || limit > 100 { limit = 20 }

	col := postsColl()

	// moderation override (optional)
	if c.Query("all") == "true" {
		return fetchPosts(c, col, bson.M{}, page, limit)
	}

	userOID := viewerOID(c)
	exact, subtree, err := viewerOrgSets(userOID)
	if err != nil { return serverError(c, err) }

	ors := []bson.M{
		{"visibility.access": bson.M{"$exists": false}},
		{"visibility.access": "public"},
	}
	if len(exact) > 0 {
		ors = append(ors, bson.M{
			"visibility.access": "org",
			"visibility.audience": bson.M{"$elemMatch": bson.M{
				"org_path": bson.M{"$in": exact},
				"scope":    "exact",
			}},
		})
	}
	if len(subtree) > 0 {
		ors = append(ors, bson.M{
			"visibility.access": "org",
			"visibility.audience": bson.M{"$elemMatch": bson.M{
				"org_path": bson.M{"$in": subtree},
				"scope":    "subtree",
			}},
		})
	}
	if userOID != primitive.NilObjectID {
		ors = append(ors, bson.M{
			"visibility.access":         "custom",
			"visibility.allow_user_ids": userOID.Hex(), // adjust if stored as ObjectIDs
		})
	}

	filter := bson.M{
		"$or":    ors,
		"status": bson.M{"$ne": "hidden"},
	}
	return fetchPosts(c, col, filter, page, limit)
}

// GET /api/posts/:id  (optional visibility check)
// @Summary      Get post
// @Description  Get post by ID (with visibility check)
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        id     path      string   true  "Post ID"
// @Param        all    query     bool     false "Show all (moderation)"
// @Success      200    {object}  Post
// @Router       /api/posts/{id} [get]
func getPost(c *fiber.Ctx) error {
	col := postsColl()

	oid, err := toOID(c.Params("id"))
	if err != nil { return badRequest(c, errors.New("invalid id")) }

	ctxx, cancel := ctx(); defer cancel()

	var post Post
	err = col.FindOne(ctxx, bson.M{"_id": oid}).Decode(&post)
	if err == mongo.ErrNoDocuments { return notFound(c) }
	if err != nil { return serverError(c, err) }

	// Enforce visibility unless ?all=true
	if c.Query("all") != "true" {
		userOID := viewerOID(c)
		exact, subtree, _ := viewerOrgSets(userOID)
		if !isPostVisibleToViewer(&post, userOID, exact, subtree) {
			return notFound(c) // or fiber.ErrForbidden
		}
	}
	return c.JSON(post)
}

// POST /api/posts
// @Summary      Create post
// @Description  Create a new post
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        createPostDTO  body      createPostDTO  true  "Post info"
// @Success      201    {object}  Post
// @Router       /api/posts [post]
func createPost(c *fiber.Ctx) error {
	col := postsColl()

	var dto createPostDTO
	if err := c.BodyParser(&dto); err != nil {
		return badRequest(c, err)
	}
	if dto.UID == "" || dto.Name == "" || dto.Username == "" || dto.Message == "" {
		return badRequest(c, errors.New("uid, name, username, message are required"))
	}

	now := time.Now().UTC()
	status := dto.Status
	if status == "" { status = "active" }

	doc := Post{
		UID:         dto.UID,
		Name:        dto.Name,
		Username:    dto.Username,
		Message:     dto.Message,
		Timestamp:   now,
		Likes:       0,
		LikedBy:     []string{},
		PostedAs:    dto.PostedAs,
		Visibility:  dto.Visibility,
		OrgOfContent: dto.OrgOfContent,
		Status:      status,
		CreatedAt:   &now,
		UpdatedAt:   &now,
	}

	ctxx, cancel := ctx(); defer cancel()
	res, err := col.InsertOne(ctxx, doc)
	if err != nil { return serverError(c, err) }

	doc.ID = res.InsertedID.(primitive.ObjectID)
	return c.Status(fiber.StatusCreated).JSON(doc)
}

// PUT /api/posts/:id
// @Summary      Update post
// @Description  Update post fields
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        id            path      string         true  "Post ID"
// @Param        updatePostDTO body      updatePostDTO  true  "Fields to update"
// @Success      200    {object}  Post
// @Router       /api/posts/{id} [put]
func updatePost(c *fiber.Ctx) error {
	col := postsColl()

	oid, err := toOID(c.Params("id"))
	if err != nil { return badRequest(c, errors.New("invalid id")) }

	var dto updatePostDTO
	if err := c.BodyParser(&dto); err != nil {
		return badRequest(c, err)
	}

	set := bson.M{}
	// legacy
	if dto.Message != nil { set["message"] = *dto.Message }
	if dto.Likes != nil   { set["likes"] = *dto.Likes }
	if dto.LikedBy != nil { set["likedBy"] = *dto.LikedBy }
	// NEW
	if dto.Status != nil       { set["status"] = *dto.Status }
	if dto.PostedAs != nil     { set["posted_as"] = dto.PostedAs }
	if dto.Visibility != nil   { set["visibility"] = dto.Visibility }
	if dto.OrgOfContent != nil { set["org_of_content"] = *dto.OrgOfContent }
	if len(set) == 0 { return badRequest(c, errors.New("no fields to update")) }

	now := time.Now().UTC()
	set["updated_at"] = now

	ctxx, cancel := ctx(); defer cancel()
	after := options.After
	opts := options.FindOneAndUpdate().SetReturnDocument(after)

	var updated Post
	err = col.FindOneAndUpdate(
		ctxx,
		bson.M{"_id": oid},
		bson.M{"$set": set},
		opts,
	).Decode(&updated)

	if err == mongo.ErrNoDocuments { return notFound(c) }
	if err != nil { return serverError(c, err) }
	return c.JSON(updated)
}

// DELETE /api/posts/:id
// @Summary      Delete post
// @Description  Delete post by ID
// @Tags         posts
// @Param        id     path      string   true  "Post ID"
// @Success      204    "No Content"
// @Router       /api/posts/{id} [delete]
func deletePost(c *fiber.Ctx) error {
	col := postsColl()

	oid, err := toOID(c.Params("id"))
	if err != nil { return badRequest(c, errors.New("invalid id")) }

	ctxx, cancel := ctx(); defer cancel()

	res, err := col.DeleteOne(ctxx, bson.M{"_id": oid})
	if err != nil { return serverError(c, err) }
	if res.DeletedCount == 0 { return notFound(c) }
	return c.SendStatus(fiber.StatusNoContent)
}

type likeDTO struct {
	UserID string `json:"userId"`
}

// POST /api/posts/:id/like
// @Summary      Like post
// @Description  Like a post by ID
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        id      path      string   true  "Post ID"
// @Param        likeDTO body      likeDTO  true  "User ID to like"
// @Success      200     {object}  Post
// @Router       /api/posts/{id}/like [post]
func likePost(c *fiber.Ctx) error {
	col := postsColl()

	oid, err := toOID(c.Params("id"))
	if err != nil { return badRequest(c, errors.New("invalid id")) }

	var dto likeDTO
	if err := c.BodyParser(&dto); err != nil || dto.UserID == "" {
		return badRequest(c, errors.New("userId is required"))
	}

	ctxx, cancel := ctx(); defer cancel()
	after := options.After
	opts := options.FindOneAndUpdate().SetReturnDocument(after)

	var updated Post
	err = col.FindOneAndUpdate(
		ctxx,
		bson.M{"_id": oid},
		bson.M{
			"$addToSet": bson.M{"likedBy": dto.UserID},
			"$inc":      bson.M{"likes": 1},
			"$set":      bson.M{"updated_at": time.Now().UTC()},
		},
		opts,
	).Decode(&updated)

	if err == mongo.ErrNoDocuments { return notFound(c) }
	if err != nil { return serverError(c, err) }
	return c.JSON(updated)
}

// POST /api/posts/:id/unlike
// @Summary      Unlike post
// @Description  Unlike a post by ID
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        id      path      string   true  "Post ID"
// @Param        likeDTO body      likeDTO  true  "User ID to unlike"
// @Success      200     {object}  Post
// @Router       /api/posts/{id}/unlike [post]
func unlikePost(c *fiber.Ctx) error {
	col := postsColl()

	oid, err := toOID(c.Params("id"))
	if err != nil { return badRequest(c, errors.New("invalid id")) }

	var dto likeDTO
	if err := c.BodyParser(&dto); err != nil || dto.UserID == "" {
		return badRequest(c, errors.New("userId is required"))
	}

	ctxx, cancel := ctx(); defer cancel()
	after := options.After
	opts := options.FindOneAndUpdate().SetReturnDocument(after)

	var updated Post
	err = col.FindOneAndUpdate(
		ctxx,
		bson.M{"_id": oid},
		bson.M{
			"$pull": bson.M{"likedBy": dto.UserID},
			"$inc":  bson.M{"likes": -1},
			"$set":  bson.M{"updated_at": time.Now().UTC()},
		},
		opts,
	).Decode(&updated)

	if err == mongo.ErrNoDocuments { return notFound(c) }
	if err != nil { return serverError(c, err) }

	// Guard: keep likes >= 0
	if updated.Likes < 0 {
		_, _ = col.UpdateByID(ctxx, oid, bson.M{"$set": bson.M{"likes": 0}})
		updated.Likes = 0
	}
	return c.JSON(updated)
}

// POST /api/posts/:id/hide
// @Summary      Hide post
// @Description  Hide a post by ID
// @Tags         posts
// @Param        id     path      string   true  "Post ID"
// @Success      204    "No Content"
// @Router       /api/posts/{id}/hide [post]
func hidePost(c *fiber.Ctx) error {
	col := postsColl()

	oid, err := toOID(c.Params("id"))
	if err != nil { return badRequest(c, errors.New("invalid id")) }

	ctxx, cancel := ctx(); defer cancel()

	_, err = col.UpdateByID(ctxx, oid, bson.M{"$set": bson.M{
		"status":     "hidden",
		"updated_at": time.Now().UTC(),
	}})
	if err != nil { return serverError(c, err) }
	return c.SendStatus(fiber.StatusNoContent)
}

// POST /api/posts/:id/unhide
// @Summary      Unhide post
// @Description  Unhide a post by ID
// @Tags         posts
// @Param        id     path      string   true  "Post ID"
// @Success      204    "No Content"
// @Router       /api/posts/{id}/unhide [post]
func unhidePost(c *fiber.Ctx) error {
	col := postsColl()

	oid, err := toOID(c.Params("id"))
	if err != nil { return badRequest(c, errors.New("invalid id")) }

	ctxx, cancel := ctx(); defer cancel()

	_, err = col.UpdateByID(ctxx, oid, bson.M{"$set": bson.M{
		"status":     "active",
		"updated_at": time.Now().UTC(),
	}})
	if err != nil { return serverError(c, err) }
	return c.SendStatus(fiber.StatusNoContent)
}

//
// ---------- Shared find helper ----------
//

func fetchPosts(c *fiber.Ctx, col *mongo.Collection, filter bson.M, page, limit int) error {
	skip := int64((page - 1) * limit)
	lim := int64(limit)

	ctxx, cancel := ctx(); defer cancel()

	findOpts := options.Find().
		SetSort(bson.D{{Key: "created_at", Value: -1}, {Key: "timestamp", Value: -1}}).
		SetSkip(skip).
		SetLimit(lim)

	cur, err := col.Find(ctxx, filter, findOpts)
	if err != nil { return serverError(c, err) }
	defer cur.Close(ctxx)

	var posts []Post
	if err := cur.All(ctxx, &posts); err != nil { return serverError(c, err) }
	return c.JSON(posts)
}

//
// ---------- Routes (no DB arg; matches your style) ----------
//

// RegisterPostRoutes wires routes under /posts so callers can pass /api.
func RegisterPostRoutes(router fiber.Router) {
	posts := router.Group("/posts") // <--- ensure routes live at /<parent>/posts

	posts.Get("/",  listPosts)
	posts.Get("/:id", getPost)

	// Protect these upstream if desired (JWT/abilities):
	posts.Post("/",           createPost)
	posts.Put("/:id",         updatePost)
	posts.Delete("/:id",      deletePost)
	posts.Post("/:id/like",   likePost)
	posts.Post("/:id/unlike", unlikePost)
	posts.Post("/:id/hide",   hidePost)
	posts.Post("/:id/unhide", unhidePost)
}