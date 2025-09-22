package api

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/config"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// ---------- DTOs ----------
type EventRequestDTO struct {
	NodeID           string     `json:"node_id"`
	Topic            string     `json:"topic"`
	Description      string     `json:"description"`
	MaxParticipation int        `json:"max_participation"`
	PostedAs         *PostedAs   `json:"posted_as,omitempty"`
	Visibility       *Visibility `json:"visibility,omitempty"`
	OrgOfContent     string      `bson:"org_of_content,omitempty" json:"org_of_content,omitempty"`
	Status           string      `bson:"status,omitempty" json:"status,omitempty"`
	Schedules        []struct {
		Date        time.Time `json:"date"`
		Time_start  time.Time `json:"time_start"`
		Time_end    time.Time `json:"time_end"`
		Location    string    `json:"location"`
		Description string    `json:"description"`
	} `json:"schedules"`
}

// Report DTOs
type EventScheduleReport struct {
	Date      time.Time `json:"date"`
	StartTime time.Time `json:"start_time"`
	EndTime   time.Time `json:"end_time"`
}
type EventReport struct {
	EventID    string                `json:"event_id"`
	EventTopic string                `json:"event_topic"`
	Schedules  []EventScheduleReport `json:"schedules"`
}

// ---------- Models ----------
type Event struct {
	ID               primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	NodeID           primitive.ObjectID `bson:"node_id" json:"node_id"`
	Topic            string             `bson:"topic" json:"topic"`
	Description      string             `bson:"description" json:"description"`
	MaxParticipation int                `bson:"max_participation" json:"max_participation"`

	PostedAs     *PostedAs   `json:"posted_as,omitempty"`
	Visibility   *Visibility `json:"visibility,omitempty"`
	OrgOfContent string      `bson:"org_of_content,omitempty" json:"org_of_content,omitempty"`
	Status       string      `bson:"status,omitempty" json:"status,omitempty"`

	CreatedAt *time.Time `bson:"created_at,omitempty" json:"created_at,omitempty"`
	UpdatedAt *time.Time `bson:"updated_at,omitempty" json:"updated_at,omitempty"`
}

type EventSchedule struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	EventID     primitive.ObjectID `bson:"event_id" json:"event_id"`
	Date        time.Time          `bson:"date" json:"date"`
	Time_start  time.Time          `bson:"time_start" json:"time_start"`
	Time_end    time.Time          `bson:"time_end" json:"time_end"`
	Location    *string            `bson:"location,omitempty" json:"location,omitempty"`
	Description *string            `bson:"description,omitempty" json:"description,omitempty"`
}

// NOTE: MembershipDoc is defined in memberships.go in the same package.
// type MembershipDoc struct { ... }  // DO NOT duplicate here

// ---------- Helpers ----------
// At top of events.go (same package), keep this tiny wrapper:
func UserIDFrom(c *fiber.Ctx) (primitive.ObjectID, error) {
	return userIDFromBearer(c)
}
// ---------- DB Insert ----------
func InsertEvent(ctx context.Context, event Event) error {
	_, err := config.DB.Collection("events").InsertOne(ctx, event)
	return err
}

func InsertSchedules(ctx context.Context, schedules []EventSchedule) error {
	if len(schedules) == 0 {
		return nil
	}
	docs := make([]interface{}, len(schedules))
	for i := range schedules {
		docs[i] = schedules[i]
	}
	_, err := config.DB.Collection("event_schedules").InsertMany(ctx, docs)
	return err
}

// ---------- Queries ----------
func GetEvent(ctx context.Context) ([]Event, error) {
	cursor, err := config.DB.Collection("events").Find(ctx, bson.M{"status": bson.M{"$ne": "hidden"}})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var events []Event
	if err := cursor.All(ctx, &events); err != nil {
		return nil, err
	}
	return events, nil
}

func GetSchedulesByEvent(ctx context.Context, eventIDlist []primitive.ObjectID) ([]EventSchedule, error) {
	collection := config.DB.Collection("event_schedules")
	filter := bson.M{"event_id": bson.M{"$in": eventIDlist}}

	cursor, err := collection.Find(ctx, filter)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var schedules []EventSchedule
	if err := cursor.All(ctx, &schedules); err != nil {
		return nil, err
	}
	return schedules, nil
}

// ---------- Create Event ----------
func CreateEventWithSchedules(body EventRequestDTO, ctx context.Context) (Event, []EventSchedule, error) {
	now := time.Now().UTC()

	nodeID, err := primitive.ObjectIDFromHex(body.NodeID)
	if err != nil {
		return Event{}, nil, fmt.Errorf("invalid NodeID: %w", err)
	}

	event := Event{
		ID:               primitive.NewObjectID(),
		NodeID:           nodeID,
		Topic:            body.Topic,
		Description:      body.Description,
		MaxParticipation: body.MaxParticipation,
		PostedAs:         body.PostedAs,
		Visibility:       body.Visibility,
		OrgOfContent:     body.OrgOfContent,
		Status:           body.Status,
		CreatedAt:        &now,
		UpdatedAt:        &now,
	}
	if err := InsertEvent(ctx, event); err != nil {
		return Event{}, nil, err
	}

	var schedules []EventSchedule
	for _, s := range body.Schedules {
		loc := s.Location
		desc := s.Description
		schedules = append(schedules, EventSchedule{
			ID:          primitive.NewObjectID(),
			EventID:     event.ID,
			Date:        s.Date,
			Time_start:  s.Time_start,
			Time_end:    s.Time_end,
			Location:    &loc,
			Description: &desc,
		})
	}
	if err := InsertSchedules(ctx, schedules); err != nil {
		return event, nil, err
	}
	return event, schedules, nil
}

// ---------- Visibility ----------
func GetVisibleEvents(viewerID primitive.ObjectID, ctx context.Context, orgSets []string) ([]map[string]interface{}, error) {
	events, err := GetEvent(ctx)
	if err != nil {
		return nil, err
	}

	var eventIDlist []primitive.ObjectID
	for _, ev := range events {
		if CheckVisibleEvent(&ev, orgSets) {
			eventIDlist = append(eventIDlist, ev.ID)
		}
	}

	schedules, err := GetSchedulesByEvent(ctx, eventIDlist)
	if err != nil {
		return nil, err
	}

	schedMap := make(map[primitive.ObjectID][]EventSchedule)
	for _, s := range schedules {
		schedMap[s.EventID] = append(schedMap[s.EventID], s)
	}

	var result []map[string]interface{}
	for _, ev := range events {
		if !CheckVisibleEvent(&ev, orgSets) {
			continue
		}
		result = append(result, map[string]interface{}{
			"event":     ev,
			"schedules": schedMap[ev.ID],
		})
	}
	return result, nil
}

func CheckVisibleEvent(event *Event, userOrgs []string) bool {
	if event.Status == "hidden" {
		return false
	}
	if event.Visibility == nil {
		return false
	}

	v := event.Visibility
	switch v.Access {
	case "public":
		return true
	case "org":
		if len(v.Audience) == 0 {
			return false
		}
		subtreeSet := map[string]struct{}{}
		for _, s := range userOrgs {
			subtreeSet[s] = struct{}{}
		}
		for _, a := range v.Audience {
			if _, ok := subtreeSet[a.OrgPath]; ok {
				return true
			}
		}
		return false
	default:
		return false
	}
}

// ---------- Membership ----------
func AllUserOrg(userID primitive.ObjectID) ([]string, error) {
	collection := config.DB.Collection("memberships")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cursor, err := collection.Find(ctx, bson.M{"user_id": userID, "active": true})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	organizeSet := map[string]struct{}{}

	for cursor.Next(ctx) {
		var m MembershipDoc
		if err := cursor.Decode(&m); err != nil {
			return nil, err
		}
		if m.OrgPath == "" {
			continue
		}
		organizeSet[m.OrgPath] = struct{}{}

		parts := strings.Split(m.OrgPath, "/")
		for i := 1; i < len(parts); i++ {
			parent := strings.Join(parts[:i], "/")
			if parent != "" {
				organizeSet[parent] = struct{}{}
			}
		}
	}

	orgs := make([]string, 0, len(organizeSet))
	for path := range organizeSet {
		orgs = append(orgs, path)
	}
	return orgs, nil
}

// ---------- Handlers ----------
func CreateEventHandler() fiber.Handler {
	return func(c *fiber.Ctx) error {
		var body EventRequestDTO
		if err := c.BodyParser(&body); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
		}
		if body.NodeID == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "NodeID is required"})
		}

		ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
		defer cancel()

		event, schedules, err := CreateEventWithSchedules(body, ctx)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
		}

		reportSchedules := make([]EventScheduleReport, len(schedules))
		for i, s := range schedules {
			reportSchedules[i] = EventScheduleReport{
				Date:      s.Date,
				StartTime: s.Time_start,
				EndTime:   s.Time_end,
			}
		}

		return c.Status(fiber.StatusCreated).JSON(EventReport{
			EventID:    event.ID.Hex(),
			EventTopic: event.Topic,
			Schedules:  reportSchedules,
		})
	}
}

func GetAllVisibleEventHandler() fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
		defer cancel()

		viewerID, err := UserIDFrom(c)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
		}

		orgSets, err := AllUserOrg(viewerID)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to get user orgs"})
		}

		events, err := GetVisibleEvents(viewerID, ctx, orgSets)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
		}

		return c.JSON(events)
	}
}

func DeleteEventHandler(c *fiber.Ctx) error {
	collection := config.DB.Collection("events")

	idHex := c.Params("id")
	eventID, err := primitive.ObjectIDFromHex(idHex)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid ID"})
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
	defer cancel()

	_, err = collection.UpdateOne(ctx, bson.M{"_id": eventID},
		bson.M{"$set": bson.M{"status": "hidden", "updated_at": time.Now()}})
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to delete event"})
	}

	return c.JSON(fiber.Map{"message": "Event deleted (soft)"})
}

// ---------- Routes ----------
func SetupRoutesEvents(r fiber.Router) {
	event := r.Group("/event")
	event.Post("/", CreateEventHandler())
	event.Get("/", GetAllVisibleEventHandler())
	event.Delete("/:id", DeleteEventHandler)
}