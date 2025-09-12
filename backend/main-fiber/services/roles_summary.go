// 

package services

import (
	"context"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

func UpdateRolesSummary(ctx context.Context, db *mongo.Database, userID any) error {
	type M struct{ OrgPath, PositionKey string }
	cur, err := db.Collection("memberships").Find(ctx, bson.M{"user_id": userID, "active": true})
	if err != nil { return err }
	var ms []M; if err := cur.All(ctx, &ms); err != nil { return err }

	type P struct{ Display map[string]string `bson:"display"` }
	type O struct{ ShortName map[string]string `bson:"short_name"` }

	type Item struct{ OrgPath, PositionKey, Label string }
	var items []Item; orgs := []string{}; pos := []string{}
	for _, m := range ms {
		var p P; db.Collection("positions").FindOne(ctx, bson.M{"key": m.PositionKey}).Decode(&p)
		var o O; db.Collection("org_units").FindOne(ctx, bson.M{"path": m.OrgPath}).Decode(&o)
		items = append(items, Item{m.OrgPath, m.PositionKey, fmt.Sprintf("%s • %s", p.Display["en"], o.ShortName["en"])})
		orgs = append(orgs, m.OrgPath); pos = append(pos, m.PositionKey)
	}
	now := time.Now()
	_, err = db.Collection("users").UpdateByID(ctx, userID, bson.M{"$set": bson.M{
		"roles_summary": bson.M{
			"updated_at":    now,
			"memberships":   items,
			"org_paths":     orgs,
			"position_keys": pos,
		},
		"updatedAt": now,
	}})
	return err
}