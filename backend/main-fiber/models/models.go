package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Membership struct {
	ID          primitive.ObjectID `bson:"_id,omitempty"     json:"_id,omitempty"`
	UserID      primitive.ObjectID `bson:"user_id"           json:"user_id"`
	OrgPath     string             `bson:"org_path"          json:"org_path"`
	PositionKey string             `bson:"position_key"      json:"position_key"`
	JoinedAt    *time.Time         `bson:"joined_at,omitempty" json:"joined_at,omitempty"`
	Active      *bool              `bson:"active,omitempty"  json:"active,omitempty"`
}
// ====== Permission ======
type Permission struct {
	ID       primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Key      string             `bson:"key" json:"key"`
	Label    string             `bson:"label,omitempty" json:"label,omitempty"`
	Category string             `bson:"category,omitempty" json:"category,omitempty"`
}

// ====== Role ======
type Role struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Name        string             `bson:"name" json:"name"`
	Label       string             `bson:"label" json:"label"`
	Permissions []string           `bson:"permissions" json:"permissions"`
}

// ====== User ======
type User struct {
	ID           primitive.ObjectID `bson:"_id,omitempty" json:"_id,omitempty"`
	SeqID        int                `bson:"id" json:"id"` // numeric app id
	FirstName    string             `bson:"firstName" json:"firstName"`
	LastName     string             `bson:"lastName" json:"lastName"`
	ThaiPrefix   string             `bson:"thaiprefix,omitempty" json:"thaiprefix,omitempty"`
	Gender       string             `bson:"gender,omitempty" json:"gender,omitempty"`
	TypePerson   string             `bson:"type_person,omitempty" json:"type_person,omitempty"`
	StudentID    string             `bson:"student_id,omitempty" json:"student_id,omitempty"`
	AdvisorID    string             `bson:"advisor_id,omitempty" json:"advisor_id,omitempty"`
	Email        string             `bson:"email" json:"email"`
	Roles        []string           `bson:"roles" json:"roles"`
	PasswordHash string             `bson:"password_hash,omitempty" json:"-"`
	CreatedAt    time.Time          `bson:"createdAt,omitempty" json:"createdAt,omitempty"`
	UpdatedAt    time.Time          `bson:"updatedAt,omitempty" json:"updatedAt,omitempty"`
}

// ====== User with role expansion ======
type UserWithRoleDetails struct {
	User        `bson:",inline"`
	RoleDetails []Role `bson:"roleDetails" json:"roleDetails"`
}