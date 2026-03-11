# xhs-growth

Small shell workflow for discovering Xiaohongshu education/training accounts with `xiaohongshu-cli`, enriching them with latest-note metadata, and generating a manual review queue.

一个基于 Shell 的小红书潜在客户账号发现工作流：按关键词搜索账号、补充最新笔记元数据，并生成可人工复核的清单。

## 中文说明

### 项目简介

这个仓库是围绕 `xiaohongshu-cli` 封装的一组 Bash 脚本，适合做轻量级账号发现和人工筛选流程。

它会完成这 3 个步骤：

1. 根据关键词批量搜索账号，例如 `AI培训` `小龙虾`
2. 去重汇总为 `accounts.json` 和 `accounts.csv`
3. 拉取每个账号的最新笔记，并生成 `manual_review.csv` / `manual_review.md`

### 文件说明

| 文件 | 作用 |
| --- | --- |
| `1_xhs_get_keyword_user_ids.sh` | 按关键词搜索账号，生成基础账号列表 |
| `2_xhs_get_user_latest_notes.sh` | 为账号补充最新笔记信息 |
| `xhs_prepare_manual_review.sh` | 生成人工复核队列 |
| `xhs-user-keywords.txt` | 默认关键词列表 |
| `output/` | 每次运行生成的结果目录 |

### 依赖

- `bash`
- `xhs` CLI，并且已经可以在 `PATH` 中直接调用
- `jq`
- 一个可用的小红书登录态

```bash
xhs login
xhs status
```

### 快速开始

使用默认关键词采集：

```bash
./1_xhs_get_keyword_user_ids.sh
```

推荐把三步流程指向同一个输出目录：

```bash
./1_xhs_get_keyword_user_ids.sh --out-dir ./output/latest
./2_xhs_get_user_latest_notes.sh --out-dir ./output/latest
./xhs_prepare_manual_review.sh --out-dir ./output/latest
```

使用自定义关键词：

```bash
./1_xhs_get_keyword_user_ids.sh "AI培训" "小龙虾"
```

测试时限制补充数量和等待时间：

```bash
./2_xhs_get_user_latest_notes.sh --out-dir ./output/latest --limit 20 --sleep 1
```

如果你的本地 CLI 子命令是 `xhs user-search`，先设置：

```bash
export XHS_SEARCH_SUBCOMMAND=user-search
```

### 输出内容

常见输出文件如下：

- `accounts.json`：去重后的账号主数据
- `accounts.csv`：便于筛选和导出的表格版本
- `raw/search/*.json`：原始搜索响应
- `raw/posts/*.json`：原始发文响应
- `collect.log` / `enrich.log`：运行日志
- `manual_review.csv` / `manual_review.md`：人工复核清单

### 注意事项

- 这些脚本默认采用 `xhs ... --json` + `jq` 的方式做结构化处理。
- `output/` 下的结果可能包含账号元数据，分享前应先做人工检查。
- 请自行确认你的使用方式符合平台条款、隐私要求和内部合规要求。

## English

### Overview

This repository is not an official Xiaohongshu tool. It is a thin Bash workflow built around `xiaohongshu-cli` for lightweight account discovery and manual review.

The workflow does three things:

1. Search accounts by keyword, such as `AI培训`
2. Deduplicate results into `accounts.json` and `accounts.csv`
3. Enrich each account with its latest post metadata and build `manual_review.csv` / `manual_review.md`

### Files

| File | Purpose |
| --- | --- |
| `1_xhs_get_keyword_user_ids.sh` | Search accounts by keyword and build the base account list |
| `2_xhs_get_user_latest_notes.sh` | Enrich matched accounts with latest-note metadata |
| `xhs_prepare_manual_review.sh` | Generate a manual review queue |
| `xhs-user-keywords.txt` | Default keyword seed list |
| `output/` | Generated run artifacts |

### Requirements

- `bash`
- `xhs` CLI available in `PATH`
- `jq`
- A valid Xiaohongshu login session

```bash
xhs login
xhs status
```

### Quick Start

Run collection with the default keyword list:

```bash
./1_xhs_get_keyword_user_ids.sh
```

Use the same output directory for the full three-step flow:

```bash
./1_xhs_get_keyword_user_ids.sh --out-dir ./output/latest
./2_xhs_get_user_latest_notes.sh --out-dir ./output/latest
./xhs_prepare_manual_review.sh --out-dir ./output/latest
```

Use custom keywords:

```bash
./1_xhs_get_keyword_user_ids.sh "AI培训" "小龙虾"
```

Limit enrichment during testing:

```bash
./2_xhs_get_user_latest_notes.sh --out-dir ./output/latest --limit 20 --sleep 1
```

If your local CLI build uses `xhs user-search`, set:

```bash
export XHS_SEARCH_SUBCOMMAND=user-search
```

### Output

Typical generated files:

- `accounts.json`: deduplicated account dataset
- `accounts.csv`: spreadsheet-friendly version of the dataset
- `raw/search/*.json`: raw search responses
- `raw/posts/*.json`: raw post responses
- `collect.log` / `enrich.log`: run logs
- `manual_review.csv` / `manual_review.md`: human review queue

### Notes

- The scripts assume JSON-first usage of `xhs` and normalize data with `jq`.
- Generated files under `output/` may contain account metadata and should be reviewed before sharing.
- Make sure your usage complies with platform terms, privacy expectations, and your own compliance requirements.
