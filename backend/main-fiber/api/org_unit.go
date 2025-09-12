// api/org_units_admin.go
package api

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func orgUnitsCtx() (context.Context, context.CancelFunc) { return context.WithTimeout(context.Background(), 10*time.Second) }
func orgUnitsCol() *mongo.Collection { return config.DB.Collection("org_units") }

type OrgUnitCreate struct {
	Path       string            `json:"path"`                 // "/faculty/eng/com"
	ParentPath string            `json:"parent_path,omitempty"`
	Name       map[string]string `json:"name"`                 // {en:"Computer Engineering"}
	ShortName  map[string]string `json:"short_name,omitempty"` // {en:"COM", th:"คอม"}
	Type       string            `json:"type"`                 // "faculty"|"program"|"club"|...
	Slug       string            `json:"slug,omitempty"`
	Status     string            `json:"status,omitempty"`     // default "active"
	Visibility string            `json:"visibility,omitempty"` // default "public"
	Sort       int               `json:"sort,omitempty"`
}
type OrgUnitUpdate struct {
	Name       map[string]string `json:"name,omitempty"`
	ShortName  map[string]string `json:"short_name,omitempty"`
	Slug       *string           `json:"slug,omitempty"`
	Status     *string           `json:"status,omitempty"`
	Visibility *string           `json:"visibility,omitempty"`
	Sort       *int              `json:"sort,omitempty"`
}
type OrgUnitDoc struct {
	Path       string            `bson:"path"        json:"path"`
	ParentPath string            `bson:"parent_path" json:"parent_path"`
	Ancestors  []string          `bson:"ancestors"   json:"ancestors"`
	Depth      int               `bson:"depth"       json:"depth"`
	Name       map[string]string `bson:"name"        json:"name"`
	ShortName  map[string]string `bson:"short_name,omitempty" json:"short_name,omitempty"`
	Type       string            `bson:"type"        json:"type"`
	Slug       string            `bson:"slug,omitempty" json:"slug,omitempty"`
	Status     string            `bson:"status"      json:"status"`
	Visibility string            `bson:"visibility"  json:"visibility"`
	Sort       int               `bson:"sort,omitempty" json:"sort,omitempty"`
	CreatedAt  time.Time         `bson:"created_at"  json:"created_at"`
	UpdatedAt  time.Time         `bson:"updated_at"  json:"updated_at"`
}

func norm(p string) string {
	if p == "" || p == "/" { return "/" }
	if !strings.HasPrefix(p, "/") { p = "/" + p }
	return strings.TrimRight(p, "/")
}
func parentOf(p string) string {
	p = norm(p)
	if p == "/" { return "/" }
	i := strings.LastIndex(p, "/")
	if i <= 0 { return "/" }
	return p[:i]
}
func ancestorsOf(p string) ([]string, int) {
	p = norm(p)
	if p == "/" { return []string{"/"}, 0 }
	segs := strings.Split(strings.TrimPrefix(p, "/"), "/")
	anc := []string{"/"}
	cur := ""
	for i := 0; i < len(segs)-1; i++ {
		cur += "/" + segs[i]
		anc = append(anc, cur)
	}
	return anc, len(segs)
}

// POST /api/org/units/node
// @Summary      Create org unit
// @Description  Create a new organization unit node
// @Tags         org_units
// @Accept       json
// @Produce      json
// @Param        OrgUnitCreate  body      OrgUnitCreate  true  "Org unit info"
// @Success      201  {object}  OrgUnitDoc
// @Router       /api/org/units/node [post]
func CreateOrgUnit(c *fiber.Ctx) error {
	var in OrgUnitCreate
	if err := c.BodyParser(&in); err != nil { return fiber.NewError(fiber.StatusBadRequest, "invalid body") }
	in.Path = norm(in.Path)
	if in.Path == "/" { return fiber.NewError(fiber.StatusBadRequest, "path '/' not allowed") }
	if in.ParentPath == "" { in.ParentPath = parentOf(in.Path) } else { in.ParentPath = norm(in.ParentPath) }
	if len(in.Name) == 0 { return fiber.NewError(fiber.StatusBadRequest, "name required") }
	if in.Type == "" { in.Type = "node" }
	if in.Status == "" { in.Status = "active" }
	if in.Visibility == "" { in.Visibility = "public" }

	ctx, cancel := orgUnitsCtx()
	defer cancel()

	// parent must exist unless "/"
	if in.ParentPath != "/" {
		if err := orgUnitsCol().FindOne(ctx, bson.M{"path": in.ParentPath}).Err(); errors.Is(err, mongo.ErrNoDocuments) {
			return fiber.NewError(fiber.StatusBadRequest, "parent_path not found")
		} else if err != nil {
			return fiber.NewError(fiber.StatusInternalServerError, "DB error")
		}
	}
	// unique
	if err := orgUnitsCol().FindOne(ctx, bson.M{"path": in.Path}).Err(); err == nil {
		return fiber.NewError(fiber.StatusConflict, "path already exists")
	}

	anc, depth := ancestorsOf(in.Path)
	now := time.Now().UTC()
	doc := OrgUnitDoc{
		Path:       in.Path,
		ParentPath: in.ParentPath,
		Ancestors:  anc,
		Depth:      depth,
		Name:       in.Name,
		ShortName:  in.ShortName,
		Type:       in.Type,
		Slug:       in.Slug,
		Status:     in.Status,
		Visibility: in.Visibility,
		Sort:       in.Sort,
		CreatedAt:  now,
		UpdatedAt:  now,
	}
	if _, err := orgUnitsCol().InsertOne(ctx, doc); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "insert failed")
	}
	return c.Status(fiber.StatusCreated).JSON(doc)
}

// GET /api/org/units/node?path=/faculty/eng/smo
// @Summary      Get org unit
// @Description  Get organization unit node by path
// @Tags         org_units
// @Accept       json
// @Produce      json
// @Param        path  query     string  true  "Org unit path"
// @Success      200  {object}  OrgUnitDoc
// @Router       /api/org/units/node [get]
func GetOrgUnit(c *fiber.Ctx) error {
	p := norm(strings.TrimSpace(c.Query("path")))
	if p == "/" || p == "" { return fiber.NewError(fiber.StatusBadRequest, "path required") }

	ctx, cancel := orgUnitsCtx()
	defer cancel()

	var out OrgUnitDoc
	if err := orgUnitsCol().FindOne(ctx, bson.M{"path": p}).Decode(&out); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) { return c.SendStatus(fiber.StatusNotFound) }
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	return c.JSON(out)
}

// PATCH /api/org/units/node?path=/faculty/eng/smo
// @Summary      Update org unit
// @Description  Update organization unit node by path
// @Tags         org_units
// @Accept       json
// @Produce      json
// @Param        path           query     string         true  "Org unit path"
// @Param        OrgUnitUpdate  body      OrgUnitUpdate  true  "Fields to update"
// @Success      200  {object}  OrgUnitDoc
// @Router       /api/org/units/node [patch]
func UpdateOrgUnit(c *fiber.Ctx) error {
	p := norm(strings.TrimSpace(c.Query("path")))
	if p == "/" || p == "" { return fiber.NewError(fiber.StatusBadRequest, "path required") }
	var in OrgUnitUpdate
	if err := c.BodyParser(&in); err != nil { return fiber.NewError(fiber.StatusBadRequest, "invalid body") }

	set := bson.M{"updated_at": time.Now().UTC()}
	if in.Name != nil { set["name"] = in.Name }
	if in.ShortName != nil { set["short_name"] = in.ShortName }
	if in.Slug != nil { set["slug"] = *in.Slug }
	if in.Status != nil { set["status"] = *in.Status }
	if in.Visibility != nil { set["visibility"] = *in.Visibility }
	if in.Sort != nil { set["sort"] = *in.Sort }
	if len(set) == 1 { return fiber.NewError(fiber.StatusBadRequest, "no fields to update") }

	ctx, cancel := orgUnitsCtx()
	defer cancel()

	opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
	var out OrgUnitDoc
	err := orgUnitsCol().FindOneAndUpdate(ctx, bson.M{"path": p}, bson.M{"$set": set}, opts).Decode(&out)
	if errors.Is(err, mongo.ErrNoDocuments) { return c.SendStatus(fiber.StatusNotFound) }
	if err != nil { return fiber.NewError(fiber.StatusInternalServerError, "update failed") }
	return c.JSON(out)
}

// DELETE /api/org/units/node?path=/faculty/eng/smo  (leaf-only)
// @Summary      Delete org unit
// @Description  Delete organization unit node by path (leaf-only)
// @Tags         org_units
// @Param        path  query     string  true  "Org unit path"
// @Success      204  "No Content"
// @Router       /api/org/units/node [delete]
func DeleteOrgUnit(c *fiber.Ctx) error {
	p := norm(strings.TrimSpace(c.Query("path")))
	if p == "/" || p == "" { return fiber.NewError(fiber.StatusBadRequest, "path required") }

	ctx, cancel := orgUnitsCtx()
	defer cancel()

	cnt, err := orgUnitsCol().CountDocuments(ctx, bson.M{"parent_path": p})
	if err != nil { return fiber.NewError(fiber.StatusInternalServerError, "DB error") }
	if cnt > 0 { return fiber.NewError(fiber.StatusConflict, "node has children; delete them first") }

	res, err := orgUnitsCol().DeleteOne(ctx, bson.M{"path": p})
	if err != nil { return fiber.NewError(fiber.StatusInternalServerError, "DB error") }
	if res.DeletedCount == 0 { return c.SendStatus(fiber.StatusNotFound) }
	return c.SendStatus(fiber.StatusNoContent)
}

func RegisterOrgAdminRoutes(r fiber.Router) {
	g := r.Group("/org/units")
	g.Get("/node", GetOrgUnit)
	g.Post("/node", CreateOrgUnit)
	g.Patch("/node", UpdateOrgUnit)
	g.Delete("/node", DeleteOrgUnit)
}