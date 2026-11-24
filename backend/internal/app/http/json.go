package http

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"mime"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/gin-gonic/gin"
)

func DecodeJSON(c *gin.Context, out any) error {
	contentType, _, err := mime.ParseMediaType(c.GetHeader("Content-Type"))
	if err != nil || contentType != "application/json" {
		return apperr.ErrValidation()
	}
	decoder := json.NewDecoder(c.Request.Body)
	var raw json.RawMessage
	if err := decoder.Decode(&raw); err != nil {
		return apperr.ErrValidation()
	}
	var object map[string]json.RawMessage
	if err := json.Unmarshal(raw, &object); err != nil || object == nil {
		return apperr.ErrValidation()
	}
	for _, value := range object {
		if bytes.Equal(bytes.TrimSpace(value), []byte("null")) {
			return apperr.ErrValidation()
		}
	}
	objectDecoder := json.NewDecoder(bytes.NewReader(raw))
	objectDecoder.DisallowUnknownFields()
	if err := objectDecoder.Decode(out); err != nil {
		return apperr.ErrValidation()
	}
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		return apperr.ErrValidation()
	}
	return nil
}
