# Автодеплой бэкенда

Push в `main` с изменениями `backend/`, `deploy/production/` или workflow собирает Linux/amd64 образ в GHCR и обновляет сервер. Pull request выполняет только сборку. Ручной запуск — Actions → Backend build and deploy → Run workflow на `main`.

- Сервер: Linux, Docker + Compose, `flock`; пользователь деплоя имеет доступ к Docker.
- Secrets GitHub: `DEPLOY_HOST`, `DEPLOY_PORT`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`.
- SSH-ключ CD отдельный; ключ сервера проверяется строго. Смена адреса/ключа требует обновления secrets после проверки.
- Образ публикуется токеном workflow; сервер получает временный токен только для скачивания. Файлы авторизации удаляются после job.
- Серверные файлы: `~/trackit/.env`, `releases/<commit>/`, `current.release`, `backups/`.
- `.env` создаётся по `deploy/production/.env.example` со случайным паролем PostgreSQL; в GitHub и Git не передаётся.
- API слушает только `127.0.0.1:8080`, PostgreSQL — `127.0.0.1:54329`. Backend использует сеть Linux-хоста; данные PostgreSQL находятся в `trackit_postgres_data`.
- Перед обновлением сохраняется `pg_dump`; успешность определяется healthcheck `/readyz` (HTTP 204). Обновляется только backend; существующий PostgreSQL не пересоздаётся.
- При неудачном старте возвращается образ и Compose предыдущего релиза. Миграции БД автоматически не откатываются; новые миграции должны поддерживать предыдущий backend.
- Деплои сериализованы GitHub concurrency и серверной блокировкой. Есть короткий перерыв при замене контейнера.
- Релизы Apple-приложения этим workflow не выпускаются. Удаление томов, импорт локальных задач и открытие публичного API сюда не входят.

Подключение к API с Mac:

```sh
ssh -N -L 18080:127.0.0.1:8080 server
```

В приложении адрес сервера: `http://127.0.0.1:18080`. Это отдельная серверная база; данные локальной базы не переносятся автоматически.

Проверка состояния на сервере:

```sh
read release image < ~/trackit/current.release
TRACKIT_ROOT=~/trackit TRACKIT_IMAGE="$image" docker compose --env-file ~/trackit/.env -f ~/trackit/releases/"$release"/compose.yaml ps
```

Ручной возврат к известному релизу: `bash ~/trackit/releases/<commit>/deploy.sh ghcr.io/alnoi/locked-in-backend@sha256:<digest>`. Снимки БД находятся в `~/trackit/backups/`; восстановление из них выполняется отдельно.
