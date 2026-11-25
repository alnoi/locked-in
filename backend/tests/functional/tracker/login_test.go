package tracker_test

import (
	"strings"
	"testing"
)

func TestLoginErrors(t *testing.T) {
	f := newFixture(t)
	f.request(t, "POST", "/auth/register", map[string]any{"username": "login_tester", "password": "login-test-password", "timeZone": "UTC"}, 201)
	tests := []struct {
		name     string
		username string
		password string
		status   int
		code     string
		message  string
	}{
		{"unknown_user", "unknown_tester", "login-test-password", 401, "user_not_found", "No user with this username was found."},
		{"unknown_user_short_password", "unknown_tester", "bad", 401, "user_not_found", "No user with this username was found."},
		{"wrong_password", "login_tester", "wrong-test-password", 401, "wrong_password", "Incorrect password."},
		{"short_password", "login_tester", "bad", 401, "wrong_password", "Incorrect password."},
		{"long_password", "login_tester", strings.Repeat("x", 257), 401, "wrong_password", "Incorrect password."},
		{"valid_login", "login_tester", "login-test-password", 200, "", ""},
		{"normalized_login", "  LOGIN_TESTER  ", "login-test-password", 200, "", ""},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := f.request(t, "POST", "/auth/login", map[string]any{"username": test.username, "password": test.password}, test.status)
			if test.code != "" {
				if result["code"] != test.code || result["message"] != test.message {
					t.Fatalf("unexpected login error: %v", result)
				}
				if _, exists := result["accessToken"]; exists {
					t.Fatal("failed login returned a session")
				}
				return
			}
			if result["accessToken"] == nil || result["accessToken"] == "" {
				t.Fatal("successful login did not return a session")
			}
		})
	}
}
