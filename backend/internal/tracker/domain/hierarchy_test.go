package domain

import (
	"testing"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func TestTaskHierarchy(t *testing.T) {
	rootID, childID, grandchildID := uuid.New(), uuid.New(), uuid.New()
	root := models.Task{ID: rootID}
	child := models.Task{ID: childID, ParentID: &rootID}
	tests := []struct {
		name    string
		value   models.Task
		tasks   []models.Task
		allowed bool
	}{
		{"root", root, nil, true},
		{"child", child, []models.Task{root}, true},
		{"third_level", models.Task{ID: grandchildID, ParentID: &childID}, []models.Task{root, child}, false},
		{"self", models.Task{ID: rootID, ParentID: &rootID}, []models.Task{root}, false},
		{"move_parent_with_children", models.Task{ID: rootID, ParentID: &grandchildID}, []models.Task{root, child, {ID: grandchildID}}, false},
		{"missing_parent", child, nil, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateTaskHierarchy(tt.value, tt.tasks)
			if (err == nil) != tt.allowed {
				t.Fatalf("allowed=%v error=%v", tt.allowed, err)
			}
		})
	}
}
func TestInheritedSelection(t *testing.T) {
	rootID, childID, leafID, tagID := uuid.New(), uuid.New(), uuid.New(), uuid.New()
	completed, open := true, false
	tests := []struct {
		name      string
		boards    []models.Board
		wantTags  int
		wantEmpty bool
		wantError bool
	}{
		{"intersection", []models.Board{{ID: rootID}, {ID: childID, ParentID: &rootID, TagIDs: []uuid.UUID{tagID}}, {ID: leafID, ParentID: &childID, FilterCompleted: &open}}, 1, false, false},
		{"contradiction", []models.Board{{ID: rootID}, {ID: childID, ParentID: &rootID, FilterCompleted: &completed}, {ID: leafID, ParentID: &childID, FilterCompleted: &open}}, 0, true, false},
		{"cycle", []models.Board{{ID: leafID, ParentID: &childID}, {ID: childID, ParentID: &leafID}}, 0, false, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := ResolveBoardSelection(leafID, tt.boards)
			if (err != nil) != tt.wantError {
				t.Fatalf("error=%v", err)
			}
			if tt.wantError {
				return
			}
			if (result.RootID == nil || *result.RootID != rootID) || len(result.TagIDs) != tt.wantTags || result.MatchNone != tt.wantEmpty {
				t.Fatalf("selection=%+v", result)
			}
		})
	}
}
func TestBoardCycle(t *testing.T) {
	first, second := uuid.New(), uuid.New()
	tests := []struct {
		name      string
		value     models.Board
		boards    []models.Board
		wantError bool
	}{
		{"root", models.Board{ID: first}, nil, false},
		{"self", models.Board{ID: first, ParentID: &first}, nil, true},
		{"descendant", models.Board{ID: first, ParentID: &second}, []models.Board{{ID: first}, {ID: second, ParentID: &first}}, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateBoardHierarchy(tt.value, tt.boards)
			if (err != nil) != tt.wantError {
				t.Fatalf("error=%v", err)
			}
		})
	}
}
