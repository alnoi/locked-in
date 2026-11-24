package report

const createQuery = `-- createBugReport
INSERT INTO
  bug_reports (
    id,
    owner_id,
    description,
    screenshot,
    screenshot_mime,
    platform,
    app_version
  )
VALUES
  (
    @id,
    @owner_id,
    @description,
    @screenshot,
    @screenshot_mime,
    @platform,
    @app_version
  )
RETURNING
  id,
  created_at`
const selectQuery = `-- getBugReportReceipts
SELECT
  id,
  created_at
FROM
  bug_reports
WHERE
  id = @id
  AND owner_id IS NOT DISTINCT FROM @owner_id`
