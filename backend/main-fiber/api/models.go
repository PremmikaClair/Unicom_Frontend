package api

import "go.mongodb.org/mongo-driver/bson/primitive"

// ---- Permission & Role ----

type PermissionDoc struct {
	ID       int    `bson:"id" json:"id"`
	Resource string `bson:"resource" json:"resource"`
	Action   string `bson:"action" json:"action"`
}

type RoleDoc struct {
	ID          string          `bson:"id" json:"id"`       // e.g. "admin"
	Name        string          `bson:"name" json:"name"`   // slug or internal name
	Label       string          `bson:"label" json:"label"` // display
	Permissions []PermissionDoc `bson:"permissions" json:"permissions"`
}

// ---- User ----
//
// Mongo _id lives in MongoID; your numeric app id is ID.
// JSON/bson tag names match your frontend model.
type User struct {
	MongoID    primitive.ObjectID `bson:"_id,omitempty" json:"-"`
	ID         int                `bson:"id" json:"id"`
	FirstName  string             `bson:"firstName" json:"firstName"`
	LastName   string             `bson:"lastName" json:"lastName"`
	ThaiPrefix string             `bson:"thaiprefix" json:"thaiprefix"`
	Gender     string             `bson:"gender" json:"gender"`
	TypePerson string             `bson:"type_person" json:"type_person"`
	StudentID  string             `bson:"student_id" json:"student_id"`
	AdvisorID  string             `bson:"advisor_id" json:"advisor_id"`
	Email      string             `bson:"email" json:"email"`
	Roles      []string           `bson:"roles" json:"roles"`
	// For auth (optional in this file; used by auth endpoints)
	PasswordHash string `bson:"password_hash,omitempty" json:"-"`
}

// UserWithRoleDetails is your expanded user for ?include=roles,permissions
type UserWithRoleDetails struct {
	User        `bson:",inline"`
	RoleDetails []RoleDoc `bson:"roleDetails,omitempty" json:"roleDetails,omitempty"`
}