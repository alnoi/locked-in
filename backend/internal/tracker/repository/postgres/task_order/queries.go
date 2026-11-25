package task_order

const selectQuery = `-- selectTaskOrders
SELECT
  task_ids,
  revision
FROM
  task_orders
WHERE
  owner_id = @scope`
const createQuery = `-- createTaskOrder
INSERT INTO
  task_orders (owner_id, task_ids)
VALUES
  (@owner_id, @task_ids)
RETURNING
  task_ids,
  revision`
const updateQuery = `-- updateTaskOrder
UPDATE task_orders
SET
  task_ids = @task_ids,
  revision = revision + 1
WHERE
  owner_id = @owner_id
RETURNING
  task_ids,
  revision`
