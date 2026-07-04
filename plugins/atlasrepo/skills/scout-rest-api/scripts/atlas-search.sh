#!/usr/bin/env bash
# AtlasRepo Scout search with automatic query broadening and graceful API errors.
#
# Usage:
#   atlas-search.sh [--compact|--pretty] <keyword> [category] [limit]
#   atlas-search.sh --version
#   atlas-search.sh --check-version
#
# Examples:
#   atlas-search.sh "notion" "Automation" 10
#   atlas-search.sh "trading bot"
#
# Behavior:
#   - With ATLAS_SCOUT_API_KEY: /api/catalog/search, broadening on empty result:
#     full query + category -> first keyword + category -> first keyword only.
#   - Without a key: /api/catalog/top (category/topic/language) + /api/recommendations.
# Output: compact JSON by default, or pretty/full JSON with --pretty; strategy goes to stderr.
set -euo pipefail

SKILL_VERSION="2.4.0"
BASE="${ATLAS_SCOUT_BASE_URL:-https://atlasrepo.com}"
KEY="${ATLAS_SCOUT_API_KEY:-}"
OUTPUT_MODE="compact"

have_jq() { command -v jq >/dev/null 2>&1; }

json_escape() {
  if have_jq; then
    jq -Rn --arg s "$1" '$s'
  else
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  fi
}

json_error() {
  local error="$1" message="$2" status="${3:-}" retry_after="${4:-}" fallback="${5:-}"
  if have_jq; then
    jq -n \
      --arg error "$error" \
      --arg message "$message" \
      --arg status "$status" \
      --arg retryAfter "$retry_after" \
      --arg fallback "$fallback" \
      '{error:$error, message:$message}
       + (if $status != "" then {httpStatus:$status} else {} end)
       + (if $retryAfter != "" then {retryAfter:$retryAfter} else {} end)
       + (if $fallback != "" then {fallback:$fallback} else {} end)'
  else
    python3 - "$error" "$message" "$status" "$retry_after" "$fallback" <<'PY'
import json, sys
error, message, status, retry_after, fallback = sys.argv[1:]
payload = {"error": error, "message": message}
if status:
    payload["httpStatus"] = status
if retry_after:
    payload["retryAfter"] = retry_after
if fallback:
    payload["fallback"] = fallback
print(json.dumps(payload, separators=(",", ":")))
PY
  fi
}

usage() {
  echo "usage: atlas-search.sh [--compact|--pretty] <keyword> [category] [limit]" >&2
  echo "       atlas-search.sh --version|--check-version" >&2
}

while [ "${1:-}" = "--compact" ] || [ "${1:-}" = "--pretty" ]; do
  case "$1" in
    --compact) OUTPUT_MODE="compact" ;;
    --pretty) OUTPUT_MODE="pretty" ;;
  esac
  shift
done

if [ "${1:-}" = "--version" ]; then
  echo "$SKILL_VERSION"
  exit 0
fi

if [ "${1:-}" = "--check-version" ]; then
  body_file="$(mktemp)"
  headers_file="$(mktemp)"
  status="$(curl -sS -D "$headers_file" -o "$body_file" -w '%{http_code}' "$BASE/api/skill/latest" || true)"
  if [ "$status" = "200" ] && have_jq && jq -e . >/dev/null 2>&1 <"$body_file"; then
    latest="$(jq -r '.skillVersion // .version // .latest // empty' <"$body_file")"
    if [ -n "$latest" ] && [ "$latest" != "$SKILL_VERSION" ]; then
      jq -n --arg current "$SKILL_VERSION" --arg latest "$latest" \
        '{status:"outdated", current:$current, latest:$latest, updateUrl:"https://github.com/Arnon-hs/atlasrepo-skills"}'
    else
      jq -n --arg current "$SKILL_VERSION" '{status:"current", current:$current}'
    fi
  else
    json_error "version_check_unavailable" "Version endpoint is not available yet." "$status" "" "Treat this as non-blocking and continue using the bundled skill."
  fi
  rm -f "$body_file" "$headers_file"
  exit 0
fi

Q="${1:-}"
if [ -z "$Q" ]; then
  usage
  exit 2
fi
CATEGORY="${2:-}"
LIMIT="${3:-10}"

compact() {
  if have_jq; then
    jq '{count: (.items // [] | length), total: (.total // null), items: [(.items // [])[]
        | {id, url, score, stars, language, categories, valueProposition, riskNotes, productionReadiness, integrationNotes, refreshedAt}]}'
  else
    cat
  fi
}

emit_catalog() {
  if [ "$OUTPUT_MODE" = "pretty" ]; then
    if have_jq; then jq .; else cat; fi
  else
    compact
  fi
}

api_get() { # path, then extra --data-urlencode args; sets API_BODY/API_STATUS/API_RETRY_AFTER globals
  local path="$1" body_file headers_file
  shift
  body_file="$(mktemp)"
  headers_file="$(mktemp)"
  if [ -n "$KEY" ]; then
    API_STATUS="$(curl -sS -G "$BASE$path" -H "x-api-key: $KEY" -D "$headers_file" -o "$body_file" -w '%{http_code}' "$@" || true)"
  else
    API_STATUS="$(curl -sS -G "$BASE$path" -D "$headers_file" -o "$body_file" -w '%{http_code}' "$@" || true)"
  fi
  API_RETRY_AFTER="$(awk 'tolower($0) ~ /^retry-after:/ {sub(/^[^:]*:[[:space:]]*/, "", $0); gsub(/\r/, "", $0); print; exit}' "$headers_file")"
  API_BODY="$(cat "$body_file")"
  rm -f "$body_file" "$headers_file"
}

api_post_json() { # path json-body; sets API_BODY/API_STATUS/API_RETRY_AFTER globals
  local path="$1" body="$2" body_file headers_file
  body_file="$(mktemp)"
  headers_file="$(mktemp)"
  if [ -n "$KEY" ]; then
    API_STATUS="$(curl -sS -X POST "$BASE$path" -H "content-type: application/json" -H "x-api-key: $KEY" -D "$headers_file" -o "$body_file" -w '%{http_code}' -d "$body" || true)"
  else
    API_STATUS="$(curl -sS -X POST "$BASE$path" -H "content-type: application/json" -D "$headers_file" -o "$body_file" -w '%{http_code}' -d "$body" || true)"
  fi
  API_RETRY_AFTER="$(awk 'tolower($0) ~ /^retry-after:/ {sub(/^[^:]*:[[:space:]]*/, "", $0); gsub(/\r/, "", $0); print; exit}' "$headers_file")"
  API_BODY="$(cat "$body_file")"
  rm -f "$body_file" "$headers_file"
}

friendly_error() { # status retry_after
  local status="$1" retry_after="${2:-}"
  case "$status" in
    401|403)
      json_error "invalid_api_key" \
        "AtlasRepo rejected ATLAS_SCOUT_API_KEY. Check the key, unset it for free endpoints, or create a new key in Account → API Keys." \
        "$status" "" "Unset ATLAS_SCOUT_API_KEY to use free endpoints: /api/catalog/top and /api/recommendations."
      ;;
    402)
      json_error "paid_key_required" \
        "Full catalog search requires a paid AtlasRepo API key. Subscribe at https://atlasrepo.com/#/pricing, then create a key in Account → API Keys and export ATLAS_SCOUT_API_KEY." \
        "$status" "" "Unset ATLAS_SCOUT_API_KEY to use free endpoints: /api/catalog/top and /api/recommendations."
      ;;
    429)
      json_error "rate_limited" \
        "AtlasRepo rate limit hit. Retry after ${retry_after:-unknown} seconds." \
        "$status" "${retry_after:-unknown}" ""
      ;;
    *)
      return 1
      ;;
  esac
}

items_count() {
  if have_jq; then jq -r '.items // [] | length'; else grep -c '"id"' || true; fi
}

paid_search() { # q [category]; sets API_BODY/API_STATUS/API_RETRY_AFTER globals
  local q="$1" cat="${2:-}" args=(--data-urlencode "q=$q" --data-urlencode "limit=$LIMIT" --data-urlencode "sort=score")
  [ -n "$cat" ] && args+=(--data-urlencode "category=$cat")
  api_get "/api/catalog/search" "${args[@]}"
}

free_search() {
  echo "strategy: no API key -> free endpoints /api/catalog/top + /api/recommendations" >&2
  local top_args=(--data-urlencode "limit=$LIMIT")
  [ -n "$CATEGORY" ] && top_args+=(--data-urlencode "category=$CATEGORY")
  api_get "/api/catalog/top" "${top_args[@]}"
  top="$API_BODY"
  if friendly_error "$API_STATUS" "$API_RETRY_AFTER"; then exit 0; fi
  if [ "$API_STATUS" -lt 200 ] || [ "$API_STATUS" -ge 300 ]; then
    json_error "atlasrepo_api_error" "AtlasRepo API returned an error from /api/catalog/top." "$API_STATUS" "" "$top"
    exit 0
  fi

  stories_body="{\"query\": $(json_escape "$Q"), \"limit\": 5}"
  api_post_json "/api/recommendations" "$stories_body"
  stories="$API_BODY"
  if friendly_error "$API_STATUS" "$API_RETRY_AFTER"; then exit 0; fi
  if [ "$API_STATUS" -lt 200 ] || [ "$API_STATUS" -ge 300 ]; then
    json_error "atlasrepo_api_error" "AtlasRepo API returned an error from /api/recommendations." "$API_STATUS" "" "$stories"
    exit 0
  fi

  if have_jq; then
    if [ "$OUTPUT_MODE" = "pretty" ]; then
      jq -n --argjson top "$top" --argjson stories "$stories" \
        '{topRepos: ($top.items // []), storyRecommendations: ($stories.stories // []), note: "Free tier. A paid API key unlocks full catalog search: https://atlasrepo.com/#/pricing"}'
    else
      jq -n --argjson top "$top" --argjson stories "$stories" \
        '{topRepos: ($top.items // [] | [.[] | {id, url, score, stars, language, categories, valueProposition, riskNotes, productionReadiness, refreshedAt}]),
          storyRecommendations: ($stories.stories // []),
          note: "Free tier. A paid API key unlocks full catalog search: https://atlasrepo.com/#/pricing"}'
    fi
  else
    echo "{\"topRepos\": $top, \"storyRecommendations\": $stories}"
  fi
}

if [ -n "$KEY" ]; then
  FIRST_WORD="${Q%% *}"
  attempts=()
  attempts+=("$Q|$CATEGORY")
  [ "$FIRST_WORD" != "$Q" ] && attempts+=("$FIRST_WORD|$CATEGORY")
  [ -n "$CATEGORY" ] && attempts+=("$FIRST_WORD|")

  for attempt in "${attempts[@]}"; do
    q="${attempt%%|*}"; cat="${attempt#*|}"
    paid_search "$q" "$cat"
    result="$API_BODY"
    if friendly_error "$API_STATUS" "$API_RETRY_AFTER"; then
      echo "strategy: paid search returned HTTP $API_STATUS; rerun without ATLAS_SCOUT_API_KEY to force free endpoints" >&2
      exit 0
    fi
    if [ "$API_STATUS" -lt 200 ] || [ "$API_STATUS" -ge 300 ]; then
      json_error "atlasrepo_api_error" "AtlasRepo API returned an error from /api/catalog/search." "$API_STATUS" "" "$result"
      exit 0
    fi
    count="$(echo "$result" | items_count)"
    if [ "${count:-0}" -gt 0 ]; then
      echo "strategy: /api/catalog/search q=\"$q\"${cat:+ category=\"$cat\"}" >&2
      echo "$result" | emit_catalog
      exit 0
    fi
  done
  echo "strategy: no catalog match after broadening (tried: ${attempts[*]}); trying free recommendations" >&2
  unset ATLAS_SCOUT_API_KEY
  KEY=""
  free_search
else
  free_search
fi
