#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/snap/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
set -a
source .env
set +a
exec 9>renew.lock
flock -n 9 || exit 0
docker run --rm --network host --read-only --tmpfs /tmp:size=32m --cap-drop ALL --cap-add DAC_OVERRIDE \
  -v "$PWD/certificates:/etc/letsencrypt" \
  -v "$PWD/webroot:/var/www/certbot" \
  -v "$PWD/certbot-work:/var/lib/letsencrypt" \
  -v "$PWD/certbot-logs:/var/log/letsencrypt" \
  "$CERTBOT_IMAGE" renew --non-interactive --no-random-sleep-on-renew
docker exec track-it-proxy nginx -t
docker exec track-it-proxy nginx -s reload
