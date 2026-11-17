package apperr

import (
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
)

func HandleConstraintViolation(err error) error {
	var failure *pgconn.PgError
	if !errors.As(err, &failure) {
		return err
	}
	switch failure.ConstraintName {
	case "tasks_pkey", "fk_boards_parent", "fk_lists_board", "fk_board_tags_board", "fk_board_tags_tag", "uniq_boards_owner_id_code", "board_tags_pkey", "uniq_users_username", "fk_lists_parent", "fk_tasks_list", "fk_tasks_parent", "fk_comments_task", "fk_task_tags_parent", "fk_task_tags_tag", "fk_list_tags_parent", "fk_list_tags_tag", "task_tags_pkey", "list_tags_pkey":
		return ErrConflict()
	case "check_boards_name", "check_boards_self_parent", "check_boards_code", "check_lists_self_parent", "check_lists_root_filter", "check_lists_name", "check_tags_name", "check_tasks_self_parent", "check_tasks_deadline", "check_tasks_duration", "check_tasks_title", "check_comments_text":
		return ErrValidation()
	}
	return err
}
