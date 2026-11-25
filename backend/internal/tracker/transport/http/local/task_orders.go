package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	apphttp "github.com/alnoi/locked-in/backend/internal/app/http"
	"github.com/gin-gonic/gin"
)

func (h *Handlers) GetTaskOrder(c *gin.Context) {
	out, err := h.usecase.GetTaskOrder(c.Request.Context(), h.actor(c))
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTaskOrderToOut(out))
}
func (h *Handlers) SetTaskOrder(c *gin.Context) {
	var request tracker_genapi.SetTaskOrderIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapSetTaskOrder(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.SetTaskOrder(c.Request.Context(), h.actor(c), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTaskOrderToOut(out))
}
