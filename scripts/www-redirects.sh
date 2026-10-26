#!/usr/bin/env bash
#
# Creates www -> non-www redirect files for upstream nginxproxy/nginx-proxy.
#
# Loops over all running containers, collects the www.* entries of their
# VIRTUAL_HOST variable and writes /etc/nginx/vhost.d/<www-host> inside the
# nginx-proxy container:
#
#     return 301 https://<host-without-www>$request_uri;
#
# (http:// instead of https:// for containers with HTTPS_METHOD=nohttps)
#
# Idempotent: files are only written when their content would change, and only
# files carrying the marker comment below are ever overwritten or pruned, so
# hand-written vhost.d files are left alone.
#
# Usage: www-redirects.sh [--dry-run] [--prune] [--restart]
#   --dry-run  only show what would change
#   --prune    remove managed redirect files whose www host no longer exists
#   --restart  restart nginx-proxy if something changed (needed for nginx-proxy
#              to pick up new/removed vhost.d files)
#
# Env: NGINX_PROXY_CONTAINER (default: nginx-proxy)

set -euo pipefail

PROXY="${NGINX_PROXY_CONTAINER:-nginx-proxy}"
DIR=/etc/nginx/vhost.d
MARKER="# managed by www-redirects.sh"
DRY_RUN=0 PRUNE=0 RESTART=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --prune)   PRUNE=1 ;;
    --restart) RESTART=1 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

docker inspect -f '{{.State.Running}}' "$PROXY" 2>/dev/null | grep -q true \
  || { echo "container '$PROXY' is not running" >&2; exit 1; }

# 1. "<www-host> <scheme>" for every www.* VIRTUAL_HOST of every running container
desired="$(
  docker ps -q | while read -r id; do
    env="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$id")"
    vhosts="$(sed -n 's/^VIRTUAL_HOST=//p' <<<"$env" | head -n1)"
    method="$(sed -n 's/^HTTPS_METHOD=//p' <<<"$env" | head -n1)"
    scheme=https; [ "$method" = nohttps ] && scheme=http
    tr ',' '\n' <<<"$vhosts" | tr -d ' \t' | while read -r host; do
      case "$host" in
        www.?*)
          case "$host" in *[*~]*) continue ;; esac   # skip wildcard / regexp hosts
          echo "$host $scheme" ;;
      esac
    done
  done | sort -u
)"

changed=0

# 2. create / update
while read -r host scheme; do
  [ -n "${host:-}" ] || continue
  file="$DIR/$host"
  content="$MARKER
return 301 $scheme://${host#www.}\$request_uri;"
  current="$(docker exec "$PROXY" cat "$file" 2>/dev/null || true)"

  if [ "$current" = "$content" ]; then
    echo "ok       $host"
  elif [ -n "$current" ] && ! grep -qxF "$MARKER" <<<"$current"; then
    echo "SKIPPED  $host ($file exists and is not managed by this script)" >&2
  else
    echo "${current:+update   }${current:-create   }$host -> $scheme://${host#www.}"
    if [ "$DRY_RUN" -eq 0 ]; then
      docker exec -i "$PROXY" sh -c "mkdir -p '$DIR' && cat > '$file'" <<<"$content"
    fi
    changed=1
  fi
done <<<"$desired"

# 3. prune stale managed files
if [ "$PRUNE" -eq 1 ]; then
  managed="$(docker exec "$PROXY" sh -c "grep -lxF '$MARKER' $DIR/www.* 2>/dev/null || true")"
  for file in $managed; do
    host="$(basename "$file")"
    if ! grep -q "^$host " <<<"$desired"; then
      echo "remove   $host"
      [ "$DRY_RUN" -eq 0 ] && docker exec "$PROXY" rm -f "$file"
      changed=1
    fi
  done
fi

# 4. restart
if [ "$changed" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  if [ "$RESTART" -eq 1 ]; then
    echo "restarting $PROXY"; docker restart "$PROXY" >/dev/null
  else
    echo "changes made - run 'docker restart $PROXY' (or pass --restart) to apply them"
  fi
fi
