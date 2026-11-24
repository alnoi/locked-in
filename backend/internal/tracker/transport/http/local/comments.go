package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func (h *Handlers) GetComments(c *gin.Context, params tracker_genapi.GetCommentsParams) {
	filters, err := mapGetComments(params)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.GetComments(c.Request.Context(), h.actor(), filters)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapCommentsToOut(out))
}
func (h *Handlers) GetComment(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.GetComment(c.Request.Context(), h.actor(), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapCommentToOut(out))
}
func (h *Handlers) CreateComment(c *gin.Context) {
	var request tracker_genapi.CreateCommentIn
	if err := decodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapCreateComment(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.CreateComment(c.Request.Context(), h.actor(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(201, mapCommentToOut(out))
}
func (h *Handlers) UpdateComment(c *gin.Context, id uuid.UUID) {
	var request tracker_genapi.UpdateCommentIn
	if err := decodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapUpdateComment(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	in.ID = id
	out, err := h.usecase.UpdateComment(c.Request.Context(), h.actor(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapCommentToOut(out))
}
func (h *Handlers) DeleteComment(c *gin.Context, id uuid.UUID) {
	if err := h.usecase.DeleteComment(c.Request.Context(), h.actor(), id); err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Status(204)
}

func (h *Handlers) RestoreComment(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.RestoreComment(c.Request.Context(), h.actor(), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapCommentToOut(out))
}
