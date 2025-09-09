package rbac

import (
	"context"
	"sort"
	"strings"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

type Membership struct {
	UserID      any    `bson:"user_id"`
	OrgPath     string `bson:"org_path"`
	PositionKey string `bson:"position_key"`
	Active      bool   `bson:"active"`
}
type Policy struct {
	OrgPath     string   `bson:"org_path"`
	PositionKey *string  `bson:"position_key,omitempty"`
	Effect      string   `bson:"effect"` // "allow" | "deny"
	Actions     []string `bson:"actions"`
	Resources   []string `bson:"resources"`
	Inherit     bool     `bson:"inherit"`
}

func scopeChain(path string) []string {
	p := strings.Trim(path, "/")
	if p == "" { return []string{"/"} }
	parts := strings.Split(p, "/")
	out := make([]string, 0, len(parts)+1)
	for i := len(parts); i >= 1; i-- { out = append(out, "/"+strings.Join(parts[:i], "/")) }
	out = append(out, "/")
	return out
}
func wild(pat, s string) bool {
	if strings.HasSuffix(pat, "*") { return strings.HasPrefix(s, strings.TrimSuffix(pat, "*")) }
	return pat == s
}
func anyWild(list []string, s string) bool { for _, p := range list { if wild(p, s) { return true } } ; return false }

type CheckInput struct {
	UserID, OrgPath, Action, Resource string
}

func Can(ctx context.Context, db *mongo.Database, in CheckInput) (bool, error) {
	// memberships
	cur, err := db.Collection("memberships").Find(ctx, bson.M{"user_id": in.UserID, "active": true})
	if err != nil { return false, err }
	var ms []Membership; if err := cur.All(ctx, &ms); err != nil { return false, err }
	posAt := map[string][]string{}
	for _, m := range ms { posAt[m.OrgPath] = append(posAt[m.OrgPath], m.PositionKey) }

	// policies
	scopes := scopeChain(in.OrgPath)
	pcur, err := db.Collection("policies").Find(ctx, bson.M{"org_path": bson.M{"$in": scopes}})
	if err != nil { return false, err }
	var ps []Policy; if err := pcur.All(ctx, &ps); err != nil { return false, err }
	byScope := map[string][]Policy{}
	for _, p := range ps { byScope[p.OrgPath] = append(byScope[p.OrgPath], p) }

	for _, scope := range scopes {
		policies := byScope[scope]
		sort.SliceStable(policies, func(i, j int) bool {
			pi, pj := policies[i], policies[j]
			if (pi.PositionKey != nil) != (pj.PositionKey != nil) { return pi.PositionKey != nil }
			if pi.Effect != pj.Effect { return pi.Effect == "deny" }
			return false
		})
		for _, p := range policies {
			if scope != in.OrgPath && !p.Inherit { continue }
			posOK := p.PositionKey == nil
			if !posOK { for _, my := range posAt[scope] { if *p.PositionKey == my { posOK = true; break } } }
			if !posOK { continue }
			if !anyWild(p.Actions, in.Action) || !anyWild(p.Resources, in.Resource) { continue }
			if p.Effect == "deny" { return false, nil }
			if p.Effect == "allow" { return true, nil }
		}
	}
	return false, nil
}