# xhs-growth

Shell helpers for a Xiaohongshu account discovery workflow built around `xiaohongshu-cli`.

这个仓库是一组围绕 `xiaohongshu-cli` 的 Shell 脚本，主要用于：

1. 按关键词搜索小红书账号
2. 去重并汇总账号信息
3. 拉取每个账号最近一条笔记
4. 基于一份人工整理好的 `manual_review.csv` 生成下游可继续处理的文本输出

## Current Files

| File | Purpose |
| --- | --- |
| `1_xhs_get_keyword_user_ids.sh` | Search accounts by keyword and build `accounts.json` / `accounts.csv` |
| `2_xhs_get_user_latest_notes.sh` | Enrich each matched account with its latest note metadata |
| `3_xhs_get_comment_cmd.sh` | Read `manual_review.csv` and render one line per note using a configurable prefix/suffix |
| `xhs-edu-keywords.txt` | Default keyword seed list |
| `output/` | Generated run artifacts |

## Requirements

- `bash`
- `python3`
- `jq`
- `xhs` CLI available in `PATH`
- A valid Xiaohongshu login session

Example:

```bash
xhs login
xhs status
```

## Workflow

### 1. Collect Accounts By Keyword

Run with the default keyword list:

```bash
./1_xhs_get_keyword_user_ids.sh --out-dir ./output/latest
```

Run with custom keywords:

```bash
./1_xhs_get_keyword_user_ids.sh --out-dir ./output/latest "AI培训" "职业培训"
```

If your local CLI build uses `xhs user-search` instead of `xhs search-user`:

```bash
export XHS_SEARCH_SUBCOMMAND=user-search
```

This step writes:

- `accounts.json`
- `accounts.csv`
- `search-results.jsonl`
- `raw/search/*.json`
- `collect.log`

### 2. Enrich Latest Notes

Use the same output directory from step 1:

```bash
./2_xhs_get_user_latest_notes.sh --out-dir ./output/latest
```

Useful flags during testing:

```bash
./2_xhs_get_user_latest_notes.sh --out-dir ./output/latest --limit 20 --sleep 1
```

This step updates:

- `accounts.json`
- `accounts.csv`
- `post-results.jsonl`
- `raw/posts/*.json`
- `enrich.log`

### 3. Render Lines From `manual_review.csv`

`3_xhs_get_comment_cmd.sh` does not create `manual_review.csv`.
It expects that file to already exist and contain at least these columns:

- `user_name`
- `user_id`
- `last_note_id`
- `last_note_title`

Example:

```bash
./3_xhs_get_comment_cmd.sh \
  --input ./output/xhs_edu_run_20260311_133107/manual_review.csv \
  --output ./output/comments.txt \
  --prefix "YYYY" \
  --suffix "XXXX"
```

The script also accepts `--search-dir` and can read matching `raw/search/*.json` files to append extra search metadata such as fan counts when available.

Typical output line:

```text
YYYY  <note_id>  XXXX  # <user_name>  <note_title>  粉丝:<count>
```

## Output Layout

Typical run directory contents:

- `accounts.json`
- `accounts.csv`
- `accounts.source.json`
- `search-results.jsonl`
- `post-results.jsonl`
- `collect.log`
- `enrich.log`
- `raw/search/*.json`
- `raw/posts/*.json`

Optional downstream files:

- `manual_review.csv`
- `comments.txt`

## Notes

- The scripts assume JSON-first usage of `xhs` and normalize data with `jq` or Python CSV parsing.
- `3_xhs_get_comment_cmd.sh` deduplicates by `last_note_id`.
- Search responses may report `fans_total` as `0` for many accounts; that value comes from the search API response, not from a separate profile fetch.
- Generated files under `output/` may contain account metadata. Review them before sharing.
- Make sure your usage complies with platform terms, privacy expectations, and your own compliance requirements.

## English Summary

This repo currently contains three shell scripts:

1. `1_xhs_get_keyword_user_ids.sh` to search users by keyword
2. `2_xhs_get_user_latest_notes.sh` to enrich each matched user with latest-note metadata
3. `3_xhs_get_comment_cmd.sh` to format one line per reviewed note from an existing `manual_review.csv`

The third script is an input formatter, not a review-queue generator. If you want a fully automated `manual_review.csv` builder inside the repo, add that as a separate script instead of assuming it already exists.
