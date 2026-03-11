#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./3_xhs_get_comment_cmd.sh [--input FILE] [--output FILE] [--prefix TEXT] [--suffix TEXT] [--search-dir DIR]

Defaults:
  --input  /Users/david/dev/xhs-growth/output/xhs_edu_run_20260311_133107/manual_review.csv
  --output /Users/david/dev/xhs-growth/output/comments.txt
  --prefix xhs comment
  --suffix -c hello
  --search-dir /Users/david/dev/xhs-growth/output/xhs_edu_run_20260311_133107/raw/search

Output format:
  YYYY  <note_id>  XXXX  # <user_name>  <note_title>  粉丝:<count>
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="${SCRIPT_DIR}/output/xhs_edu_run_20260311_133107/manual_review.csv"
OUTPUT_FILE="${SCRIPT_DIR}/output/comments.txt"
PREFIX="xhs comment"
SUFFIX="-c hello"
SEARCH_DIR="${SCRIPT_DIR}/output/xhs_edu_run_20260311_133107/raw/search"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT_FILE="${2:?missing value for --input}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:?missing value for --output}"
      shift 2
      ;;
    --prefix)
      PREFIX="${2:?missing value for --prefix}"
      shift 2
      ;;
    --suffix)
      SUFFIX="${2:?missing value for --suffix}"
      shift 2
      ;;
    --search-dir)
      SEARCH_DIR="${2:?missing value for --search-dir}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$INPUT_FILE" ]]; then
  printf 'Missing input CSV: %s\n' "$INPUT_FILE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

python3 - "$INPUT_FILE" "$OUTPUT_FILE" "$PREFIX" "$SUFFIX" "$SEARCH_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

input_file = Path(sys.argv[1])
output_file = Path(sys.argv[2])
prefix = sys.argv[3]
suffix = sys.argv[4]
search_dir = Path(sys.argv[5])

def clean(value: str) -> str:
    return " ".join((value or "").replace("\r", " ").replace("\n", " ").split())

def load_fans_map(directory: Path) -> dict[str, str]:
    fans_by_user: dict[str, int] = {}
    if not directory.is_dir():
        return {}

    for json_file in sorted(directory.glob("*.json")):
        try:
            payload = json.loads(json_file.read_text(encoding="utf-8"))
        except Exception:
            continue

        for item in payload.get("user_info_dtos", []) or []:
            base = item.get("user_base_dto") or {}
            user_id = clean(base.get("user_id") or item.get("user_id") or "")
            if not user_id:
                continue
            fans_total = item.get("fans_total")
            try:
                fans_value = int(fans_total)
            except (TypeError, ValueError):
                continue
            prev = fans_by_user.get(user_id)
            if prev is None or fans_value > prev:
                fans_by_user[user_id] = fans_value

    return {user_id: str(count) for user_id, count in fans_by_user.items()}

fans_map = load_fans_map(search_dir)

with input_file.open("r", encoding="utf-8-sig", newline="") as src:
    reader = csv.DictReader(src)
    rows = []
    seen = set()
    for row in reader:
        note_id = clean(row.get("last_note_id") or "")
        if not note_id or note_id in seen:
            continue
        seen.add(note_id)
        user_name = clean(row.get("user_name") or "")
        note_title = clean(row.get("last_note_title") or "")
        user_id = clean(row.get("user_id") or "")
        fans = clean(row.get("fans") or row.get("fans_total") or fans_map.get(user_id, ""))
        fans_suffix = f"  粉丝:{fans}" if fans else ""
        rows.append(f"{prefix}  {note_id}  {suffix}  # {user_name}  {note_title}{fans_suffix}")

with output_file.open("w", encoding="utf-8", newline="") as dst:
    dst.write("\n".join(rows))
    if rows:
        dst.write("\n")
PY

printf 'Wrote %s\n' "$OUTPUT_FILE"
