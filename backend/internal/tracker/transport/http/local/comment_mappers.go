package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapCommentToOut(value models.Comment) tracker_genapi.CommentOut {
	return tracker_genapi.CommentOut{Id: value.ID, CreatedAt: value.CreatedAt, UpdatedAt: value.UpdatedAt, TaskID: value.TaskID, Text: value.Text}
}
func mapCommentsToOut(value models.GetCommentsOut) tracker_genapi.GetCommentsOut {
	items := make([]tracker_genapi.CommentOut, 0, len(value.Items))
	for _, item := range value.Items {
		items = append(items, mapCommentToOut(item))
	}
	return tracker_genapi.GetCommentsOut{Items: items, Total: value.Total}
}
func mapCreateComment(value tracker_genapi.CreateCommentIn) (models.CreateCommentIn, error) {
	in := models.CreateCommentIn{TaskID: value.TaskID, Text: value.Text}
	if err := models.ValidateComment(in.Text); err != nil {
		return in, err
	}
	return in, nil
}
func mapUpdateComment(value tracker_genapi.UpdateCommentIn) (models.UpdateCommentIn, error) {
	in := models.UpdateCommentIn{Text: value.Text}
	if in.Text != nil {
		if err := models.ValidateComment(*in.Text); err != nil {
			return in, err
		}
	}
	return in, nil
}
