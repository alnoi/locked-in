# Locked In backend

Go 1.27+, Docker; Node.js и golangci-lint нужны для проверок. PostgreSQL. Локальная версия с одним пользователем без регистрации.

```sh
cp .env.example .env
npm ci
make up
make run
```

API: `http://127.0.0.1:8080/api/v1`. Миграции Goose применяются при старте; каждая таблица — отдельный файл с Up/Down.
Сервис слушает только loopback; доступ с iPhone и публичный запуск добавим вместе с аутентификацией.

- `GET /me` — локальный пользователь.
- `/boards`, `/lists`, `/tags`, `/tasks`, `/comments` — GET/POST; `/{id}` — GET/PATCH/DELETE.
- `POST /tasks/{id}/complete`, `/reopen` — выполнение и возврат в работу.
- `GET /tasks?boardID=…` — задачи доски с наследованием фильтров; listID дополнительно сужает список.
- `GET /lists?boardID=…` — исходные списки доски, включая наследуемые.
- `GET /tasks?plannedFrom=…&plannedTo=…` — пересечения с интервалом календаря, RFC3339.
- `GET /comments?taskID=…` — комментарии задачи.

Контракт: `api/service/local_tracker/openapi.yaml`. Генерация: `make gen-oapi`.
PATCH: отсутствующее поле не меняется; nullable-поля очищаются через `clear<Field>: true`, теги — через `tagIDs: []`.
Доска содержит списки; дочерняя доска фильтрует задачи по всем указанным тегам и выполнению, сохраняя списки.
Удаление — мягкое; используемые теги, непустые списки и задачи с детьми возвращают 409.

Проверки: `make fmt`, `make lint`, `make unit-test`.
Интеграция: `TEST_DATABASE_URL=postgres://… make integration-tests`.
Тесты создают отдельную схему внутри указанной БД и удаляют её после прогона.

Исходная общая миграция сохранена только в tests/functional/tracker/testdata/ для проверки перехода старой локальной БД без потери данных.
