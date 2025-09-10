// api/org_units.go
package api

import (
	"context"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

// ---- Collection ----
func orgUnitsColl() *mongo.Collection { return config.DB.Collection("org_units") }

// ---- DB model (decode minimal fields; extra fields are ignored) ----
type orgUnitDoc struct {
	OrgPath   string            `bson:"org_path"`                  // "/faculty/eng/com"
	Parent    string            `bson:"parent_path,omitempty"`     // optional; if missing we derive from OrgPath
	Type      string            `bson:"type,omitempty"`            // "faculty" | "club" | ...
	Label     map[string]string `bson:"label,omitempty"`           // { en:"Computer Engineering", th:"..." }
	ShortName string            `bson:"short_name,omitempty"`      // "COM"
	Sort      int               `bson:"sort,omitempty"`            // optional explicit ordering
}

// ---- Response node ----
type OrgUnitNode struct {
	OrgPath   string         `json:"org_path"`
	Type      string         `json:"type,omitempty"`
	Label     string         `json:"label,omitempty"`       // best-fit single label for convenience
	Labels    map[string]string `json:"labels,omitempty"`   // full labels by lang
	ShortName string         `json:"short_name,omitempty"`
	Children  []*OrgUnitNode `json:"children,omitempty"`
	Sort      int            `json:"-"`
}

// parent from an org_path like "/faculty/eng/com" -> "/faculty/eng"
// returns "" for top-level (e.g., "/faculty")
func parentFromPath(p string) string {
	p = strings.TrimSuffix(p, "/")
	if p == "" || p == "/" {
		return ""
	}
	i := strings.LastIndex(p, "/")
	if i <= 0 {
		return ""
	}
	return p[:i]
}

// choose a display label
func pickLabel(labels map[string]string, lang string, short string, orgPath string) string {
	if lang != "" {
		if v, ok := labels[lang]; ok && v != "" {
			return v
		}
	}
	// try any label
	for _, v := range labels {
		if v != "" {
			return v
		}
	}
	// fallback short name
	if short != "" {
		return short
	}
	// fallback last segment of path
	parts := strings.Split(strings.Trim(orgPath, "/"), "/")
	if len(parts) > 0 {
		return parts[len(parts)-1]
	}
	return orgPath
}

// GET /api/org/units/tree?start=/faculty/&depth=0&lang=en
func GetOrgTree(c *fiber.Ctx) error {
	start := strings.TrimSpace(c.Query("start"))
	lang := strings.TrimSpace(c.Query("lang"))
	depthQ := strings.TrimSpace(c.Query("depth"))

	limitDepth := 0 // 0 = unlimited
	if depthQ != "" {
		if n, err := strconv.Atoi(depthQ); err == nil && n >= 0 {
			limitDepth = n
		}
	}

	// Build a filter that works whether the collection uses "org_path" or "path"
	filter := bson.M{}
	if start != "" {
		if !strings.HasSuffix(start, "/") && start != "/" {
			start = start + "/"
		}
		re := bson.M{"$regex": "^" + regexp.QuoteMeta(start)}
		filter["$or"] = []bson.M{
			{"org_path": re},
			{"path": re},
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cur, err := orgUnitsColl().Find(ctx, filter)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "DB error")
	}
	defer cur.Close(ctx)

	var raws []bson.M
	if err := cur.All(ctx, &raws); err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "decode error: "+err.Error())
	}
	if len(raws) == 0 {
		return c.JSON([]OrgUnitNode{})
	}

	// helpers
	asString := func(v any) string {
		switch t := v.(type) {
		case string:
			return t
		case []byte:
			return string(t)
		default:
			return ""
		}
	}
	toInt := func(v any) int {
		switch t := v.(type) {
		case int: return t
		case int32: return int(t)
		case int64: return int(t)
		case float64: return int(t)
		case float32: return int(t)
		case string:
			if n, err := strconv.Atoi(t); err == nil { return n }
			return 0
		default: return 0
		}
	}
	// Accept label/name/short_name as map or string
	extractStrMap := func(v any) map[string]string {
		out := map[string]string{}
		switch t := v.(type) {
		case map[string]any:
			for k, vv := range t { out[asString(k)] = asString(vv) }
		case bson.M:
			for k, vv := range t { out[k] = asString(vv) }
		case string:
			if t != "" { out["en"] = t }
		}
		return out
	}

	// Build nodes
	nodes := map[string]*OrgUnitNode{}
	type link struct{ child, parent string }
	links := []link{}

	for _, r := range raws {
		// path field: prefer "org_path", fallback to "path"
		orgPath := asString(r["org_path"])
		if orgPath == "" {
			orgPath = asString(r["path"])
		}
		if orgPath == "" {
			// skip malformed rows
			continue
		}

		parent := asString(r["parent_path"])
		if parent == "" {
			parent = parentFromPath(orgPath)
		}

		// labels: prefer "name" (your schema) then "label"
		nameMap := extractStrMap(r["name"])
		labelMap := extractStrMap(r["label"])
		labels := nameMap
		if len(labels) == 0 {
			labels = labelMap
		}

		// short_name: may be string or map
		shortStr := asString(r["short_name"])
		if shortStr == "" {
			shortMap := extractStrMap(r["short_name"])
			if lang != "" && shortMap[lang] != "" {
				shortStr = shortMap[lang]
			} else {
				for _, v := range shortMap { shortStr = v; break }
			}
		}

		lbl := pickLabel(labels, lang, shortStr, orgPath)
		sortVal := toInt(r["sort"])
		typ := asString(r["type"])

		nodes[orgPath] = &OrgUnitNode{
			OrgPath:   orgPath,
			Type:      typ,
			Label:     lbl,
			Labels:    labels,
			ShortName: shortStr,
			Children:  []*OrgUnitNode{},
			Sort:      sortVal,
		}
		links = append(links, link{child: orgPath, parent: parent})
	}

	// Link into a forest
	roots := []*OrgUnitNode{}
	for _, lk := range links {
		child := nodes[lk.child]
		if child == nil { continue }
		if lk.parent == "" || nodes[lk.parent] == nil {
			roots = append(roots, child)
		} else {
			nodes[lk.parent].Children = append(nodes[lk.parent].Children, child)
		}
	}

	// Sort children
	var sortChildren func(ns []*OrgUnitNode)
	sortChildren = func(ns []*OrgUnitNode) {
		sort.Slice(ns, func(i, j int) bool {
			if ns[i].Sort != ns[j].Sort { return ns[i].Sort < ns[j].Sort }
			return strings.ToLower(ns[i].Label) < strings.ToLower(ns[j].Label)
		})
		for _, ch := range ns { if len(ch.Children) > 0 { sortChildren(ch.Children) } }
	}
	sortChildren(roots)

	// Depth prune
	if limitDepth > 0 {
		var prune func(list []*OrgUnitNode, d int)
		prune = func(list []*OrgUnitNode, d int) {
			if d >= limitDepth {
				for _, n := range list { n.Children = nil }
				return
			}
			for _, n := range list { prune(n.Children, d+1) }
		}
		prune(roots, 1)
	}

	return c.JSON(roots)
}

// Register router
func RegisterOrgRoutes(router fiber.Router) {
	// tree endpoint
	router.Get("/org/units/tree", GetOrgTree)
}