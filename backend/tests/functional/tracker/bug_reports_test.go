package tracker_test

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/png"
	"net/http"
	"os"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestBugReports(t *testing.T) {
	tests := []struct {
		name string
		run  func(*testing.T, *fixture, *pgxpool.Pool)
	}{
		{"stored_screenshot_and_idempotent_retry", func(t *testing.T, f *fixture, pool *pgxpool.Pool) {
			var picture bytes.Buffer
			if err := png.Encode(&picture, image.NewNRGBA(image.Rect(0, 0, 2, 2))); err != nil {
				t.Fatal(err)
			}
			id := uuid.New()
			body := map[string]any{"id": id.String(), "description": "  Calendar layout is broken  ", "platform": "ios", "appVersion": "1.0", "screenshotBase64": base64.StdEncoding.EncodeToString(picture.Bytes()), "screenshotMime": "image/png"}
			first := f.request(t, "POST", "/bug-reports", body, 201)
			again := f.request(t, "POST", "/bug-reports", body, 201)
			if first["id"] != id.String() || again["createdAt"] != first["createdAt"] {
				t.Fatal("retry did not preserve receipt")
			}
			query := `-- verifyBugReportAttachment
SELECT description, screenshot, screenshot_mime FROM bug_reports WHERE id = @id`
			rows, err := pool.Query(context.Background(), query, pgx.NamedArgs{"id": id})
			if err != nil {
				t.Fatal(err)
			}
			type stored struct {
				Description string `db:"description"`
				Screenshot  []byte `db:"screenshot"`
				Mime        string `db:"screenshot_mime"`
			}
			value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[stored])
			if err != nil {
				t.Fatal(err)
			}
			if value.Description != "Calendar layout is broken" || value.Mime != "image/png" || !bytes.Equal(value.Screenshot, picture.Bytes()) {
				t.Fatal("report text or image was not stored correctly")
			}
			var count int
			if err := pool.QueryRow(context.Background(), "SELECT count(*) FROM bug_reports WHERE id = @id", pgx.NamedArgs{"id": id}).Scan(&count); err != nil {
				t.Fatal(err)
			}
			if count != 1 {
				t.Fatal("retry inserted a duplicate")
			}
			account := f.request(t, "POST", "/auth/register", map[string]any{"username": "report_tester", "password": "test-report-password", "timeZone": "UTC", "avatarEmoji": ""}, 201)
			token := account["accessToken"].(string)
			user := account["user"].(map[string]any)
			ownedID := uuid.New()
			bugReportRequest(t, f, map[string]any{"id": ownedID.String(), "description": "Profile controls", "platform": "macos", "appVersion": "1.0"}, token, 201)
			var ownedCount int
			if err := pool.QueryRow(context.Background(), "SELECT count(*) FROM bug_reports WHERE id = @id AND owner_id = @owner_id AND screenshot IS NULL", pgx.NamedArgs{"id": ownedID, "owner_id": user["id"]}).Scan(&ownedCount); err != nil {
				t.Fatal(err)
			}
			if ownedCount != 1 {
				t.Fatal("verified author was not stored or optional attachment was not null")
			}
			bugReportRequest(t, f, body, token, 409)
		}},
		{"validation_and_author_cannot_be_forged", func(t *testing.T, f *fixture, _ *pgxpool.Pool) {
			cases := []struct {
				name  string
				extra map[string]any
			}{
				{"missing_description", map[string]any{"description": " "}},
				{"invalid_base64", map[string]any{"screenshotBase64": "?", "screenshotMime": "image/png"}},
				{"empty_attachment", map[string]any{"screenshotBase64": "", "screenshotMime": "image/png"}},
				{"not_an_image", map[string]any{"screenshotBase64": base64.StdEncoding.EncodeToString([]byte("<svg>not a raster</svg>")), "screenshotMime": "image/png"}},
				{"oversize", map[string]any{"screenshotBase64": base64.StdEncoding.EncodeToString(make([]byte, 524289)), "screenshotMime": "image/jpeg"}},
				{"forged_author", map[string]any{"ownerID": uuid.NewString()}},
			}
			for _, test := range cases {
				t.Run(test.name, func(t *testing.T) {
					body := map[string]any{"id": uuid.NewString(), "description": "A bug", "platform": "ios", "appVersion": "1.0"}
					for key, value := range test.extra {
						body[key] = value
					}
					f.request(t, "POST", "/bug-reports", body, 400)
				})
			}
		}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			f := newFixture(t)
			config, err := pgxpool.ParseConfig(os.Getenv("TEST_DATABASE_URL"))
			if err != nil {
				t.Fatal(err)
			}
			config.ConnConfig.RuntimeParams["search_path"] = pgx.Identifier{f.settings.Postgres.Schema}.Sanitize()
			pool, err := pgxpool.NewWithConfig(context.Background(), config)
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(pool.Close)
			test.run(t, f, pool)
		})
	}
}

func bugReportRequest(t *testing.T, f *fixture, body map[string]any, token string, status int) {
	t.Helper()
	encoded, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	request, err := http.NewRequestWithContext(context.Background(), "POST", f.server.URL+"/api/v1/bug-reports", bytes.NewReader(encoded))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer "+token)
	response, err := f.server.Client().Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != status {
		t.Fatalf("report status = %d, want %d", response.StatusCode, status)
	}
}
