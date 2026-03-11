#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./1_xhs_get_keyword_user_ids.sh [--out-dir DIR] [--keyword-file FILE] [keyword1 keyword2 ...]

Notes:
  - Defaults to keywords from ./xhs-edu-keywords.txt when no keywords are passed.
  - The local usage examples in this repo use `xhs search-user`. If your CLI build uses
    `xhs user-search`, set XHS_SEARCH_SUBCOMMAND=user-search before running.
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

write_accounts_csv() {
  local json_file="$1"
  local csv_file="$2"

  jq -r '
    ([
      "keywords",
      "user_name",
      "user_id",
      "red_id",
      "desc",
      "last_note_id",
      "last_note_title",
      "last_note_xsec_token",
      "last_note_cursor",
      "search_hits",
      "posts_error"
    ] | @csv),
    (.[] | [
      (.keywords // ""),
      (.user_name // ""),
      (.user_id // ""),
      (.red_id // ""),
      (.desc // ""),
      (.last_note_id // ""),
      (.last_note_title // ""),
      (.last_note_xsec_token // ""),
      (.last_note_cursor // ""),
      ((.search_hits // 0) | tostring),
      (.posts_error // "")
    ] | @csv)
  ' "$json_file" > "$csv_file"
}

rebuild_accounts() {
  local search_jsonl="$1"
  local accounts_json="$2"
  local csv_file="$3"

  if [[ ! -s "$search_jsonl" ]]; then
    printf '[]\n' > "$accounts_json"
    write_accounts_csv "$accounts_json" "$csv_file"
    return
  fi

  jq -s '
    map(select(.user_id != ""))
    | group_by(.user_id)
    | map({
        keywords: (map(.keyword) | map(select(length > 0)) | unique | sort | join("|")),
        user_name: (map(.user_name) | map(select(length > 0)) | first // ""),
        user_id: .[0].user_id,
        red_id: (map(.red_id) | map(select(length > 0)) | first // ""),
        desc: (map(.desc) | map(select(length > 0)) | first // ""),
        last_note_id: "",
        last_note_title: "",
        last_note_xsec_token: "",
        last_note_cursor: "",
        search_hits: length,
        posts_error: ""
      })
    | sort_by(.user_name, .user_id)
  ' "$search_jsonl" > "$accounts_json"

  write_accounts_csv "$accounts_json" "$csv_file"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUT_DIR="$SCRIPT_DIR/output/xhs_edu_$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="$DEFAULT_OUT_DIR"
KEYWORD_FILE="$SCRIPT_DIR/xhs-edu-keywords.txt"
SLEEP_SECONDS="${SLEEP_SECONDS:-1}"
SEARCH_SUBCOMMAND="${XHS_SEARCH_SUBCOMMAND:-search-user}"
POSITIONAL_KEYWORDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:?missing value for --out-dir}"
      shift 2
      ;;
    --keyword-file)
      KEYWORD_FILE="${2:?missing value for --keyword-file}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL_KEYWORDS+=("$1")
      shift
      ;;
  esac
done

require_cmd xhs
require_cmd jq

case "$SEARCH_SUBCOMMAND" in
  search-user|user-search)
    ;;
  *)
    printf 'Unsupported XHS_SEARCH_SUBCOMMAND: %s\n' "$SEARCH_SUBCOMMAND" >&2
    exit 1
    ;;
esac

mkdir -p "$OUT_DIR/raw/search"
SEARCH_JSONL="$OUT_DIR/search-results.jsonl"
ACCOUNTS_JSON="$OUT_DIR/accounts.json"
CSV_FILE="$OUT_DIR/accounts.csv"
KEYWORDS_USED="$OUT_DIR/keywords.used.txt"
LOG_FILE="$OUT_DIR/collect.log"
: > "$SEARCH_JSONL"
: > "$KEYWORDS_USED"
: > "$LOG_FILE"

KEYWORDS=()
if [[ ${#POSITIONAL_KEYWORDS[@]} -gt 0 ]]; then
  KEYWORDS=("${POSITIONAL_KEYWORDS[@]}")
else
  if [[ ! -f "$KEYWORD_FILE" ]]; then
    printf 'Keyword file not found: %s\n' "$KEYWORD_FILE" >&2
    exit 1
  fi
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    KEYWORDS+=("$line")
  done < "$KEYWORD_FILE"
fi

if [[ ${#KEYWORDS[@]} -eq 0 ]]; then
  printf 'No keywords to search.\n' >&2
  exit 1
fi

log "Output directory: $OUT_DIR"
log "Using subcommand: xhs $SEARCH_SUBCOMMAND"
rebuild_accounts "$SEARCH_JSONL" "$ACCOUNTS_JSON" "$CSV_FILE"

for i in "${!KEYWORDS[@]}"; do
  keyword="${KEYWORDS[$i]}"
  raw_file="$OUT_DIR/raw/search/$(printf '%03d' "$((i + 1))").json"
  err_file="$OUT_DIR/raw/search/$(printf '%03d' "$((i + 1))").stderr.log"

  printf '%s\n' "$keyword" >> "$KEYWORDS_USED"
  log "Searching keyword [$((i + 1))/${#KEYWORDS[@]}]: $keyword"

  if xhs "$SEARCH_SUBCOMMAND" "$keyword" --json >"$raw_file" 2>"$err_file"; then
    jq -c --arg keyword "$keyword" '
      (.user_info_dtos // .users // [])
      | .[]
      | (.user_base_dto // .)
      | {
          keyword: $keyword,
          user_name: (.user_nickname // .nickname // ""),
          user_id: (.user_id // ""),
          red_id: (.red_id // ""),
          desc: ((.desc // "")
            | gsub("[\r\n]+"; " ")
            | gsub("\\s+"; " ")
            | sub("^ "; "")
            | sub(" $"; ""))
        }
      | select(.user_id != "")
    ' "$raw_file" >> "$SEARCH_JSONL"

    rebuild_accounts "$SEARCH_JSONL" "$ACCOUNTS_JSON" "$CSV_FILE"
    match_count="$(jq '((.user_info_dtos // .users // []) | length)' "$raw_file")"
    printf '[%s] ok keyword=%s matches=%s\n' "$(date '+%F %T')" "$keyword" "$match_count" >> "$LOG_FILE"
  else
    err_msg="$(tr '\n' ' ' < "$err_file" | sed 's/[[:space:]]\+/ /g')"
    printf '[%s] failed keyword=%s error=%s\n' "$(date '+%F %T')" "$keyword" "$err_msg" >> "$LOG_FILE"
    log "Search failed for keyword: $keyword"
  fi

  sleep "$SLEEP_SECONDS"
done

log "Done."
log "Accounts JSON: $ACCOUNTS_JSON"
log "Accounts CSV:  $CSV_FILE"
log "Raw search dir: $OUT_DIR/raw/search"
