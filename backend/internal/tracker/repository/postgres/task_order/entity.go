package task_order

import "github.com/google/uuid"

type entity struct {
	TaskIDs  []uuid.UUID `db:"task_ids"`
	Revision int64       `db:"revision"`
}
