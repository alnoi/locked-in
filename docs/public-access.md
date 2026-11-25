# Публичный доступ TrackIt

API: `https://78.17.64.41`, без SSH-туннеля. На Mac и iPhone использовать одинаковый адрес и серверный аккаунт.

- Nginx в отдельном Compose-проекте `~/trackit/edge`, контейнер `track-it-proxy`; backend и PostgreSQL остаются на loopback. Порты SSH и Minecraft не меняются.
- Исходники: `deploy/edge`. На сервер копируются конфиги/скрипты; `.env` содержит закреплённые digest образов и PUBLIC_HOST. `nginx.conf` генерируется из шаблона заменой `__PUBLIC_HOST__`.
- Доверенный сертификат Let’s Encrypt для IP: certbot 5.10, профиль shortlived, cert-name trackit, webroot `/var/www/certbot`. Каталоги certificates, webroot, certbot-work, certbot-logs остаются на сервере и в Git не попадают.
- Сертификат живёт около 6 дней. `renew.sh` проверяет продление каждые 6 часов и перезагружает конфигурацию Nginx без остановки сервиса. Проверка: certbot renew --dry-run в тех же томах; в журналах — тег trackit-certificates.
- Ограничения: 10 запросов/сек с IP с burst 60; суммарно 100/сек с burst 120; 20 одновременных запросов с IP, 100 всего; тело до 1 MiB, таймауты 10–20 секунд.
- Вход/регистрация: 20 запросов/мин с IP с burst 5 и 60/мин суммарно с burst 10.
- 10 превышений лимита, неудачных входов или запросов неизвестных путей в минуту дают бан IP на 10 минут перед бэкендом. Ответ HTTP 429, JSON rate_limited и Retry-After; новые попытки не продлевают бан. Память ограничена, состояние общее для workers и сохраняется при reload; перезапуск контейнера сбрасывает временные баны.
- Входящий X-Real-IP/X-Forwarded-For полностью перезаписывается адресом TCP-клиента. Backend доверяет только loopback-прокси через SERVER_TRUSTED_PROXIES.
- Проверка/снятие бана с сервера: `curl 'http://127.0.0.1:8081/bans?ip=CLIENT_IP'` / `curl -X DELETE 'http://127.0.0.1:8081/bans?ip=CLIENT_IP'`. Этот интерфейс слушает только loopback.
- Журналы не содержат тела, паролей, токенов и query string; файлы abuse/error ротируются каждые 5 минут при размере >10 MiB, до трёх архивов. Ошибки обновления сертификата/ротации доступны через journalctl -t trackit-certificates / -t trackit-edge-logs.
- Запуск: `docker compose --env-file .env -f compose.yaml up -d --wait`. Перед reload: `docker exec track-it-proxy nginx -t`. Проверка логики: `node --test deploy/edge/guard.test.mjs`.
- Сервер использует Docker Snap; no-new-privileges несовместим с его AppArmor-профилем. Прокси read-only, с ограничениями памяти/CPU/PID и только необходимыми capabilities.
- Это защита API от флуда и перебора. Защиту от насыщения сетевого канала обеспечивает провайдер/внешний анти-DDoS.
