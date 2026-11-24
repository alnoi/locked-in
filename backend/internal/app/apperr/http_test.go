package apperr

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestWriteErrorRedactsDetails(t *testing.T) {
	tests := []struct {
		name    string
		failure error
		status  int
		code    ErrorCode
		message string
	}{
		{"unexpected", errors.New("postgres password=secret SELECT private_table"), 500, CodeInternal, "Internal error. Please contact support."},
		{"unknown business code", &Error{Code: "private_business_failure", Status: 400, Message: "private constraint"}, 500, CodeInternal, "Internal error. Please contact support."},
		{"untrusted message and status", &Error{Code: CodeValidation, Status: 200, Message: "SQL constraint with private data"}, 400, CodeValidation, "Check the request fields and try again."},
		{"wrapped credentials", fmt.Errorf("Login: %w", ErrInvalidCredentials()), 401, CodeInvalidCredentials, "Incorrect username or password."},
		{"duplicate login", ErrUsernameTaken(), 409, CodeUsernameTaken, "This username is already taken."},
		{"unavailable", ErrUnavailable(), 503, CodeUnavailable, "No connection with server. Please try again later."},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			context, _ := gin.CreateTestContext(recorder)
			WriteError(context, test.failure)
			if recorder.Code != test.status {
				t.Fatalf("status = %d, want %d", recorder.Code, test.status)
			}
			var body struct {
				Code    ErrorCode
				Message string
			}
			if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
				t.Fatal(err)
			}
			if body.Code != test.code || body.Message != test.message {
				t.Fatalf("unsafe or incorrect response: %s", recorder.Body.String())
			}
		})
	}
}
