# xhs-growth

Small shell workflow for finding Xiaohongshu education/training accounts with `xiaohongshu-cli`, enriching them with the latest note, and producing a manual review queue.

## What this does

1. Search Xiaohongshu users with a keyword list such as `教育培训`, `职业培训`, `AI培训`.
2. Deduplicate accounts into `accounts.json` and `accounts.csv`.
3. Fetch each account's latest post metadata.
4. Build `manual_review.csv` and `manual_review.md` for human review.

## Files

- `xhs_collect_edu_accounts.sh`: search accounts by keyword and build the base account list
- `xhs_enrich_latest_notes.sh`: fetch each matched account's latest note
- `xhs_prepare_manual_review.sh`: generate a manual review queue
- `xhs-edu-keywords.txt`: default keyword seed list
- `output/`: generated run artifacts

## Prerequisites

- `xhs` CLI available in `PATH`
- `jq`
- A valid Xiaohongshu login session for the CLI

Example:

```bash
xhs login
xhs status
```

## Usage

Run the default collection flow:

```bash
./xhs_collect_edu_accounts.sh
```

Use a custom output directory:

```bash
./xhs_collect_edu_accounts.sh --out-dir ./output/latest
./xhs_enrich_latest_notes.sh --out-dir ./output/latest
./xhs_prepare_manual_review.sh --out-dir ./output/latest
```

Use custom keywords:

```bash
./xhs_collect_edu_accounts.sh "教育培训" "AI培训" "职业培训"
```

Limit enrichment during testing:

```bash
./xhs_enrich_latest_notes.sh --out-dir ./output/latest --limit 20 --sleep 1
```

## Output

Typical generated files:

- `accounts.json`
- `accounts.csv`
- `raw/search/*.json`
- `raw/posts/*.json`
- `manual_review.csv`
- `manual_review.md`

## Notes

- Scripts assume JSON-first usage of `xhs` and use `jq` for normalization.
- Generated data under `output/` may contain scraped account metadata; review before publishing.
