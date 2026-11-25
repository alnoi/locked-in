package local

import (
	"github.com/AlekSi/pointer"
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapSetTaskOrder(value tracker_genapi.SetTaskOrderIn) (models.SetTaskOrderIn, error) {
	in := models.SetTaskOrderIn{TaskIDs: value.TaskIDs, InitializeOnly: pointer.Get(value.InitializeOnly)}
	return in, in.Validate()
}
func mapTaskOrderToOut(value models.TaskOrder) tracker_genapi.TaskOrderOut {
	return tracker_genapi.TaskOrderOut{TaskIDs: value.TaskIDs, Revision: value.Revision}
}
