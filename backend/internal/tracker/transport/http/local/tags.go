package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func (h *Handlers) GetTags(c *gin.Context, params tracker_genapi.GetTagsParams) {
	filters, err := mapGetTags(params)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.GetTags(c.Request.Context(), h.actor(), filters)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTagsToOut(out))
}
func (h *Handlers) GetTag(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.GetTag(c.Request.Context(), h.actor(), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTagToOut(out))
}
func (h *Handlers) CreateTag(c *gin.Context) {
	var request tracker_genapi.CreateTagIn
	if err := decodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapCreateTag(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.CreateTag(c.Request.Context(), h.actor(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(201, mapTagToOut(out))
}
func (h *Handlers) UpdateTag(c *gin.Context, id uuid.UUID) {
	var request tracker_genapi.UpdateTagIn
	if err := decodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapUpdateTag(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	in.ID = id
	out, err := h.usecase.UpdateTag(c.Request.Context(), h.actor(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTagToOut(out))
}
func (h *Handlers) DeleteTag(c *gin.Context, id uuid.UUID) {
	if err := h.usecase.DeleteTag(c.Request.Context(), h.actor(), id); err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Status(204)
}
