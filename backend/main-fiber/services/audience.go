package services

import (
	"context"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

type Audience struct {
	ExactOrgPaths []string
	AudienceKeys  []string
}

func GetAudience(ctx context.Context, db *mongo.Database, userID any) (Audience, error) {
	type M struct{ OrgPath string; OrgAncestors []string `bson:"org_ancestors"` }
	cur, err := db.Collection("memberships").Find(ctx, bson.M{"user_id": userID, "active": true})
	if err != nil { return Audience{}, err }
	var ms []M; if err := cur.All(ctx, &ms); err != nil { return Audience{}, err }

	setExact := map[string]struct{}{}
	setKeys := map[string]struct{}{}
	for _, m := range ms {
		setExact[m.OrgPath] = struct{}{}
		for _, a := range m.OrgAncestors { setKeys[a] = struct{}{} }
		setKeys[m.OrgPath] = struct{}{}
	}
	var exact, keys []string
	for k := range setExact { exact = append(exact, k) }
	for k := range setKeys { keys = append(keys, k) }
	return Audience{ExactOrgPaths: exact, AudienceKeys: keys}, nil
}