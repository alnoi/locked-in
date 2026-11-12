package tracker_test

import "testing"

func TestTaskReminderLifecycle(t *testing.T) {
	tests := []struct {
		name string
		mode string
	}{{"notification", "notification"}, {"alarm", "alarm"}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			task := f.request(t, "POST", "/tasks", map[string]any{"title": "Reminder", "plannedAt": "2030-01-02T10:00:00Z", "reminderMode": tt.mode, "reminderMinutesBefore": 5}, 201)
			id := task["id"].(string)
			if task["reminderMode"] != tt.mode || task["reminderMinutesBefore"] != float64(5) {
				t.Fatalf("reminder not saved: %v", task)
			}
			updated := f.request(t, "PATCH", "/tasks/"+id, map[string]any{"title": "Renamed"}, 200)
			if updated["reminderMode"] != tt.mode {
				t.Fatal("unrelated patch cleared reminder")
			}
			f.request(t, "PATCH", "/tasks/"+id, map[string]any{"clearPlannedAt": true}, 400)
			updated = f.request(t, "PATCH", "/tasks/"+id, map[string]any{"reminderMode": "none", "clearPlannedAt": true}, 200)
			if updated["reminderMode"] != "none" {
				t.Fatal("reminder not disabled")
			}
		})
	}
}
func TestTaskReminderValidation(t *testing.T) {
	tests := []struct {
		name   string
		body   map[string]any
		status int
	}{
		{"date_only_notification", map[string]any{"title": "Date", "deadlineDate": "2030-01-02", "reminderMode": "notification"}, 201},
		{"date_only_alarm", map[string]any{"title": "Date", "deadlineDate": "2030-01-02", "reminderMode": "alarm"}, 400},
		{"missing_date", map[string]any{"title": "Date", "reminderMode": "notification"}, 400},
		{"invalid_mode", map[string]any{"title": "Date", "reminderMode": "invalid"}, 400},
		{"negative_offset", map[string]any{"title": "Date", "reminderMinutesBefore": -1}, 400},
		{"too_early", map[string]any{"title": "Date", "reminderMinutesBefore": 10081}, 400},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) { f := newFixture(t); f.request(t, "POST", "/tasks", tt.body, tt.status) })
	}
}
