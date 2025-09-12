package api

import (
    "context"
    "os"
    "strings"

    "github.com/gofiber/fiber/v2"
    "github.com/golang-jwt/jwt/v5"
    "github.com/pllus/main-fiber/config"
    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
)

// collections
// use usersCol() from user.go
func membershipsCol() *mongo.Collection  { return config.DB.Collection("memberships") }
func policiesColAuthz() *mongo.Collection { return config.DB.Collection("policies") }

// userIDFromBearer extracts ObjectID from Authorization Bearer token using the same secret as auth.go
func userIDFromBearer(c *fiber.Ctx) (primitive.ObjectID, error) {
    auth := c.Get("Authorization")
    if !strings.HasPrefix(auth, "Bearer ") {
        return primitive.NilObjectID, fiber.NewError(fiber.StatusUnauthorized, "missing token")
    }
    tok := strings.TrimPrefix(auth, "Bearer ")
    claims := jwt.MapClaims{}
    t, err := jwt.ParseWithClaims(tok, claims, func(t *jwt.Token) (interface{}, error) { return jwtSecret(), nil })
    if err != nil || !t.Valid {
        return primitive.NilObjectID, fiber.NewError(fiber.StatusUnauthorized, "invalid token")
    }
    sub, _ := claims["sub"].(string)
    return primitive.ObjectIDFromHex(sub)
}

// normalize org path: ensure leading '/', strip trailing '/', except root "/"
func normPath(p string) string {
    p = strings.TrimSpace(p)
    if p == "" || p == "/" { return "/" }
    if !strings.HasPrefix(p, "/") { p = "/" + p }
    p = strings.TrimRight(p, "/")
    if p == "" { return "/" }
    return p
}

func sameOrChild(prefix, p string) bool {
    prefix = normPath(prefix)
    p = normPath(p)
    if prefix == "/" { return true }
    if p == prefix { return true }
    return strings.HasPrefix(p, prefix+"/")
}

// minimal user projection to detect root/admin
type userRolesMini struct {
    Roles []string `bson:"roles"`
}

func isRootAdmin(ctx context.Context, uid primitive.ObjectID) bool {
    if uid == primitive.NilObjectID { return false }

    // Primary rule: membership at root with position_key = "root_admin"
    // Accept legacy variations of active/status flags
    var rootMem struct{ ID primitive.ObjectID `bson:"_id"` }
    _ = membershipsCol().FindOne(ctx, bson.M{
        "user_id":      uid,
        "org_path":     "/",
        "position_key": "root_admin",
        "$or": []bson.M{{"active": true}, {"active": bson.M{"$exists": false}}, {"status": "active"}, {"status": bson.M{"$exists": false}}},
    }).Decode(&rootMem)
    if !rootMem.ID.IsZero() { return true }

    // Fallback: roles array on user doc
    var u userRolesMini
    _ = usersCol().FindOne(ctx, bson.M{"_id": uid}).Decode(&u)
    for _, r := range u.Roles {
        if r == "root" || r == "admin" {
            return true
        }
    }
    return false
}

// Note: reuse Policy type from policies.go within the same package

type membershipMiniAuthz struct {
    OrgPath     string `bson:"org_path"`
    PositionKey string `bson:"position_key"`
    Active      bool   `bson:"active"`
}

// Can evaluates whether user can perform action at resourcePath following simple allow-list semantics.
func Can(ctx context.Context, userID primitive.ObjectID, action, resourcePath string) (bool, error) {
    // Temporary global bypass via env flag for troubleshooting
    if v := strings.ToLower(os.Getenv("AUTHZ_BYPASS")); v == "true" || v == "1" { return true, nil }
    if v := strings.ToLower(os.Getenv("RBAC_BYPASS")); v == "true" || v == "1" { return true, nil }
    // root bypass
    if isRootAdmin(ctx, userID) {
        return true, nil
    }

    resourcePath = normPath(resourcePath)
    if userID == primitive.NilObjectID {
        return false, nil
    }

    // 1) active memberships for the user (accept legacy docs without 'active' or with status="active")
    memCur, err := membershipsCol().Find(ctx, bson.M{
        "user_id": userID,
        "$or": []bson.M{
            {"active": true},
            {"active": bson.M{"$exists": false}},
            {"status": "active"},
            {"status": bson.M{"$exists": false}},
        },
    })
    if err != nil { return false, err }
    var mems []membershipMiniAuthz
    if err := memCur.All(ctx, &mems); err != nil { return false, err }
    if len(mems) == 0 { return false, nil }

    // collect position keys & map by org_path
    posSet := map[string]struct{}{}
    for _, m := range mems { posSet[m.PositionKey] = struct{}{} }
    posArr := make([]string, 0, len(posSet))
    for k := range posSet { posArr = append(posArr, k) }

    // 2) enabled policies for those positions
    pFilter := bson.M{"enabled": true}
    if len(posArr) > 0 { pFilter["position_key"] = bson.M{"$in": posArr} }
    pCur, err := policiesColAuthz().Find(ctx, pFilter)
    if err != nil { return false, err }
    var pols []Policy
    if err := pCur.All(ctx, &pols); err != nil { return false, err }

    // 3) evaluate: policy.where.org_prefix is a prefix for membership org_path
    a := strings.TrimSpace(action)
    for _, m := range mems {
        for _, p := range pols {
            if p.PositionKey != m.PositionKey { continue }
            if !p.Enabled || strings.ToLower(p.Effect) == "deny" { continue }
            // policy attaches to memberships whose org_path starts with policy.where.org_prefix
            if !strings.HasPrefix(normPath(m.OrgPath), normPath(p.Where.OrgPrefix)) { continue }

            // action match
            match := false
            for _, pa := range p.Actions {
                if pa == "*" || pa == a { match = true; break }
            }
            if !match { continue }

            // scope rule (exact => only the membership node; subtree => membership node + descendants)
            switch p.Scope {
            case "subtree":
                if sameOrChild(m.OrgPath, resourcePath) { return true, nil }
            case "exact":
                fallthrough
            default:
                if normPath(m.OrgPath) == resourcePath { return true, nil }
            }
        }
    }
    return false, nil
}

// AbilitiesFor computes a map[action]bool for a fixed set at org path using Can.
func AbilitiesFor(ctx context.Context, userID primitive.ObjectID, orgPath string, actions []string) (map[string]bool, error) {
    out := map[string]bool{}
    // root/admin -> everything true
    if isRootAdmin(ctx, userID) {
        for _, a := range actions { out[a] = true }
        return out, nil
    }
    for _, a := range actions {
        ok, err := Can(ctx, userID, a, orgPath)
        if err != nil { return nil, err }
        out[a] = ok
    }
    return out, nil
}
