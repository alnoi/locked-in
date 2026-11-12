-- +goose Up
CREATE TABLE IF NOT EXISTS boards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users (id),
  name text NOT NULL,
  parent_id uuid,
  filter_completed boolean,
  code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT uniq_boards_owner_id_id UNIQUE (owner_id, id),
  CONSTRAINT uniq_boards_owner_id_code UNIQUE (owner_id, code),
  CONSTRAINT fk_boards_parent FOREIGN KEY (owner_id, parent_id) REFERENCES boards (owner_id, id),
  CONSTRAINT check_boards_name CHECK (length(btrim(name)) > 0),
  CONSTRAINT check_boards_self_parent CHECK (parent_id IS DISTINCT FROM id),
  CONSTRAINT check_boards_code CHECK (
    code IS NULL
    OR (
      code = 'general'
      AND parent_id IS NULL
      AND filter_completed IS NULL
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_boards_owner_id ON boards (owner_id)
WHERE
  deleted_at IS NULL;

INSERT INTO
  boards (owner_id, name, code)
SELECT
  id,
  'Общая доска',
  'general'
FROM
  users
ON CONFLICT (owner_id, code) DO NOTHING;

INSERT INTO
  boards (
    id,
    owner_id,
    name,
    parent_id,
    filter_completed,
    created_at,
    updated_at
  )
SELECT
  legacy.id,
  legacy.owner_id,
  legacy.name,
  general.id,
  legacy.filter_completed,
  legacy.created_at,
  legacy.updated_at
FROM
  lists legacy
  JOIN boards general ON general.owner_id = legacy.owner_id
  AND general.code = 'general'
WHERE
  legacy.parent_id IS NOT NULL
  AND legacy.deleted_at IS NULL
ON CONFLICT (id) DO NOTHING;

UPDATE boards child
SET
  parent_id = parent.id
FROM
  lists legacy
  JOIN boards parent ON parent.id = legacy.parent_id
  AND parent.owner_id = legacy.owner_id
WHERE
  child.id = legacy.id
  AND child.owner_id = legacy.owner_id
  AND child.code IS NULL
  AND child.deleted_at IS NULL
  AND legacy.deleted_at IS NULL;

-- +goose Down
DROP TABLE IF EXISTS boards;
