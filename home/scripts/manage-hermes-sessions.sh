#!/usr/bin/env bash
# 管理 Hermes 历史对话（会话）
#   - 列表 / 搜索 / 详情 / 重命名 / 置顶 / 导出 / 归档 / 删除 / 清理 / 统计优化
#   - 修改一律走 `hermes sessions ...` 官方命令；脚本只用只读方式读数据库做展示
#   - 默认进交互菜单；也支持子命令一次性执行
#
# 用法：manage-hermes-sessions.sh [子命令] [参数]
#       不带参数 = 交互菜单；`help` 查看全部子命令
set -euo pipefail

HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
STATE_DB="${HERMES_SESSIONS_DB:-$HERMES_HOME_DIR/state.db}"

die() { printf '错误：%s\n' "$*" >&2; exit 1; }

# ---------- 依赖检查 ----------
HERMES_BIN=""
if command -v hermes >/dev/null 2>&1; then
  HERMES_BIN=$(command -v hermes)
fi
[[ -n "$HERMES_BIN" ]] || die "找不到 hermes 命令（修改会话需要 Hermes Agent CLI）。"

# python 仅用于只读查询：需要一个带 sqlite3 的解释器。
# 注意 hermes 在 NixOS 上常常是 bash 包装脚本（shebang 是 bash），不能直接拿它的解释器。
find_python() {
  local cand base seen=""
  local -a candidates=()
  if [[ -n "$HERMES_BIN" ]]; then
    cand=$(sed -n '1s/^#!*[[:space:]]*//p' "$HERMES_BIN" | awk '{print $1}')
    base=${cand##*/}
    if [[ "$base" == python* && -x "$cand" ]]; then
      candidates+=("$cand")
    fi
  fi
  for cand in python3 python3.14 python3.13 python3.12 python3.11 python; do
    if command -v "$cand" >/dev/null 2>&1; then
      candidates+=("$(command -v "$cand")")
    fi
  done
  candidates+=(/run/current-system/sw/bin/python3 /nix/var/nix/profiles/default/bin/python3 /usr/bin/python3)
  for cand in "${candidates[@]}"; do
    [[ -x "$cand" ]] || continue
    case ":$seen:" in *":$cand:"*) continue ;; esac
    seen="$seen:$cand"
    if "$cand" -c 'import sqlite3' >/dev/null 2>&1; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}
PY=$(find_python || true)
[[ -n "$PY" ]] || die "找不到带 sqlite3 的 python3（只读查询会话库需要它）。NixOS 上请把 python3 加进 home.packages 后重试。"
[[ -f "$STATE_DB" ]] || die "会话数据库不存在：$STATE_DB"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/hermes-sessions.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
HELPER="$WORK/helper.py"

# ---------- 只读查询助手 ----------
cat > "$HELPER" <<'PY_HELPER'
import json, os, sqlite3, sys, time, unicodedata

DB_PATH, CMD, ARGV = sys.argv[1], sys.argv[2], sys.argv[3:]
PROTECTED = {p for p in os.environ.get("PROTECTED_IDS", "").split(",") if p}
TITLE_EXPR = "coalesce(nullif(trim(title), ''), '')"
SEEN_EXPR = "coalesce(last_activity_at, ended_at, started_at)"
SOURCE_SQL = "source in ('local','cli','tui','qqbot')"


def conn():
    c = sqlite3.connect("file:%s?mode=ro" % DB_PATH, uri=True)
    c.row_factory = sqlite3.Row
    return c


def charw(ch):
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def width(s):
    return sum(charw(c) for c in s)


def tidy(s):
    return " ".join((s or "").replace("\t", " ").split())


def clip(s, limit):
    s = tidy(s)
    if width(s) <= limit:
        return s
    out, acc = "", 0
    for c in s:
        if acc + charw(c) > limit - 1:
            break
        out += c
        acc += charw(c)
    return out + "…"


def cell(s, limit):
    v = clip(s, limit)
    return v + " " * max(0, limit - width(v))


def ago(ts):
    if not ts:
        return "—"
    d = time.time() - float(ts)
    if d < 120:
        return "刚刚"
    if d < 3600:
        return "%d 分钟前" % int(d // 60)
    if d < 86400:
        return "%d 小时前" % int(d // 3600)
    if d < 86400 * 30:
        return "%d 天前" % int(d // 86400)
    return time.strftime("%Y-%m-%d", time.localtime(ts))


def stamp(ts):
    return time.strftime("%Y-%m-%d %H:%M", time.localtime(ts)) if ts else "—"


def humansize(n):
    n = float(n or 0)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return ("%.0f %s" % (n, unit)) if unit == "B" else ("%.1f %s" % (n, unit))
        n /= 1024


def humantok(n):
    n = int(n or 0)
    if n >= 1000000:
        return "%.1fM" % (n / 1000000.0)
    if n >= 1000:
        return "%.1fk" % (n / 1000.0)
    return str(n)


def short_id(sid):
    if len(sid) <= 12:
        return sid
    if sid.startswith("local-"):
        return sid[6:14]
    if "_" in sid:
        return sid[-8:]
    return sid[:8]


def fetch(limit, source, include_all):
    q = ("select id, source, %s as title, message_count, tool_call_count,"
         " coalesce(input_tokens,0)+coalesce(output_tokens,0) as tokens,"
         " coalesce(estimated_cost_usd,0) as cost, %s as seen,"
         " pinned, archived, hidden, cwd, model from sessions" % (TITLE_EXPR, SEEN_EXPR))
    where, params = [SOURCE_SQL], []
    if not include_all:
        where.append("archived = 0 and hidden = 0")
    if source:
        where.append("source = ?")
        params.append(source)
    if where:
        q += " where " + " and ".join(where)
    q += " order by pinned desc, seen desc"
    if limit and limit > 0:
        q += " limit %d" % limit
    c = conn()
    try:
        return c.execute(q, params).fetchall()
    finally:
        c.close()


def marks(row):
    out = []
    if row["pinned"]:
        out.append("★")
    if row["archived"]:
        out.append("归档")
    if row["id"] in PROTECTED:
        out.append("运行中")
    return " ".join(out)


def render(rows, tsv_path=None):
    hdr = ("#", "来源", "消息", "Tokens", "最近活动", "短 ID", "标题")
    w = (3, 8, 5, 7, 10, 10, 44)
    head = "  ".join(cell(h, w[i]) for i, h in enumerate(hdr)).rstrip()
    print(head)
    print("─" * width(head))
    tsv = open(tsv_path, "w", encoding="utf-8") if tsv_path else None
    try:
        for n, row in enumerate(rows, 1):
            title = row["title"] or "（未命名）"
            m = marks(row)
            if m:
                title = "%s  %s" % (title, m)
            print("  ".join([
                cell(str(n), w[0]), cell(row["source"] or "-", w[1]),
                cell(str(row["message_count"] or 0), w[2]), cell(humantok(row["tokens"]), w[3]),
                cell(ago(row["seen"]), w[4]), cell(short_id(row["id"]), w[5]),
                clip(title, w[6]),
            ]).rstrip())
            if tsv:
                tsv.write("\t".join([str(n), row["id"], row["source"] or "-",
                                     str(row["message_count"] or 0), ago(row["seen"]),
                                     tidy(row["title"]) or "（未命名）", m]) + "\n")
    finally:
        if tsv:
            tsv.close()


if CMD == "list":
    limit, source, include_all, tsv_path = 20, None, False, None
    i = 0
    while i < len(ARGV):
        a = ARGV[i]
        if a in ("--limit", "-n"):
            limit = int(ARGV[i + 1]); i += 2
        elif a == "--source":
            source = ARGV[i + 1]; i += 2
        elif a in ("--all", "-a"):
            include_all, limit = True, 0; i += 1
        elif a == "--tsv":
            tsv_path = ARGV[i + 1]; i += 2
        else:
            i += 1
    rows = fetch(limit, source, include_all)
    if not rows:
        print("（没有会话）")
        sys.exit(0)
    render(rows, tsv_path)

elif CMD == "tsv":
    for n, row in enumerate(fetch(0, None, False), 1):
        print("\t".join([str(n), row["id"], row["source"] or "-",
                         str(row["message_count"] or 0), ago(row["seen"]),
                         tidy(row["title"]) or "（未命名）", marks(row)]))

elif CMD == "search":
    kw = ARGV[0]
    like = "%" + kw + "%"
    c = conn()
    try:
        rows = c.execute(
            "select s.id, s.source, " + TITLE_EXPR + " as title, s.message_count,"
            " " + SEEN_EXPR + " as seen,"
            " (select count(*) from messages m where m.session_id = s.id and m.content like ?) as hits"
            " from sessions s where s.source in ('local','cli','tui','qqbot') and s.archived = 0 and s.hidden = 0"
            " and (s.title like ? or exists (select 1 from messages m2"
            "   where m2.session_id = s.id and m2.content like ?))"
            " order by seen desc limit 30", (like, like, like)).fetchall()
        if not rows:
            print("（没有匹配「%s」的会话）" % kw)
            sys.exit(0)
        w = (3, 8, 5, 10, 10, 40)
        head = "  ".join([cell("#", w[0]), cell("来源", w[1]), cell("命中", w[2]),
                          cell("最近活动", w[3]), cell("短 ID", w[4]),
                          cell("标题", w[5])]).rstrip()
        print(head)
        print("─" * width(head))
        for n, row in enumerate(rows, 1):
            print("  ".join([cell(str(n), w[0]), cell(row["source"] or "-", w[1]),
                             cell(str(row["hits"]), w[2]), cell(ago(row["seen"]), w[3]),
                             cell(short_id(row["id"]), w[4]),
                             clip(row["title"] or "（未命名）", w[5])]).rstrip())
            if row["hits"]:
                hit = c.execute("select content from messages where session_id = ? and role = 'user'"
                                " and content like ? order by timestamp limit 1",
                                (row["id"], like)).fetchone()
                if hit:
                    print("      ↳ " + clip(hit["content"], 92))
    finally:
        c.close()

elif CMD == "show":
    sid = ARGV[0]
    c = conn()
    try:
        row = c.execute("select * from sessions where " + SOURCE_SQL + " and id = ?", (sid,)).fetchone()
        if row is None:
            print("找不到会话：%s" % sid, file=sys.stderr)
            sys.exit(2)
        first = c.execute("select content from messages where session_id = ? and role = 'user'"
                          " and coalesce(content,'') != '' order by timestamp limit 1",
                          (sid,)).fetchone()
        last = c.execute("select role, tool_name, content from messages where session_id = ?"
                         " and coalesce(content,'') != '' order by timestamp desc limit 1",
                         (sid,)).fetchone()
        flags = [k for k, v in (("置顶", row["pinned"]), ("归档", row["archived"]),
                                ("隐藏", row["hidden"])) if v]
        cols = [("ID", row["id"]), ("标题", row["title"] or "（未命名）"),
                ("来源", row["source"]), ("模型", row["model"] or "-"),
                ("消息数", "%s 条（%s 次工具调用）" % (row["message_count"] or 0,
                                                   row["tool_call_count"] or 0)),
                ("Token", "输入 %s / 输出 %s / 缓存读 %s" % (humantok(row["input_tokens"]),
                                                          humantok(row["output_tokens"]),
                                                          humantok(row["cache_read_tokens"]))),
                ("费用", "$%.4f" % (row["estimated_cost_usd"] or 0.0)),
                ("开始时间", stamp(row["started_at"])),
                ("最近活动", stamp(row["last_activity_at"])),
                ("结束", "%s（%s）" % (stamp(row["ended_at"]), row["end_reason"] or "-")
                 if row["ended_at"] else "-"),
                ("工作目录", row["cwd"] or "-"),
                ("标记", "、".join(flags) if flags else "-")]
        for k, v in cols:
            print("%s : %s" % (k + " " * max(0, 10 - width(k)), v))
        print()
        print("首条用户消息：")
        print("  " + (clip(first["content"], 400) if first else "（无）"))
        print("最后一条消息：")
        if last:
            who = last["role"] + ("/" + last["tool_name"] if last["tool_name"] else "")
            print("  [%s] %s" % (who, clip(last["content"], 400)))
        else:
            print("  （无）")
    finally:
        c.close()

elif CMD == "resolve":
    needle = ARGV[0]
    c = conn()
    try:
        found = c.execute("select id, title from sessions where " + SOURCE_SQL + " and id = ?", (needle,)).fetchall()
        if not found:
            found = c.execute("select id, title from sessions where " + SOURCE_SQL + " and id like ?",
                              (needle + "%",)).fetchall()
        if not found:
            found = c.execute("select id, title from sessions where " + SOURCE_SQL + " and id like ?",
                              ("%" + needle,)).fetchall()
        if not found:
            found = c.execute("select id, title from sessions where " + SOURCE_SQL + " and id like ?",
                              ("%" + needle + "%",)).fetchall()
    finally:
        c.close()
    if not found:
        print("找不到匹配「%s」的会话。" % needle, file=sys.stderr)
        sys.exit(2)
    if len(found) > 1:
        print("「%s」匹配到 %d 个会话，请写长一点以唯一定位：" % (needle, len(found)), file=sys.stderr)
        for r in found[:10]:
            print("  %s  %s" % (r["id"], tidy(r["title"]) or "（未命名）"), file=sys.stderr)
        sys.exit(2)
    print(found[0]["id"])

elif CMD == "active":
    ids = set()
    for key in ("HERMES_SESSION_ID", "HERMES_SESSION_CHAT_ID"):
        v = os.environ.get(key, "").strip()
        if v:
            ids.add(v)
    path = os.path.join(os.path.dirname(DB_PATH), "runtime", "active_sessions.json")
    live = []
    try:
        with open(path, encoding="utf-8") as fh:
            for entry in (json.load(fh).get("entries") or []):
                if isinstance(entry, dict) and entry.get("session_id"):
                    live.append(str(entry["session_id"]))
    except Exception:
        pass
    c = conn()
    try:
        allids = [r[0] for r in c.execute("select id from sessions")]
    finally:
        c.close()
    for sid in live:
        for full in allids:
            if sid == full or sid.endswith(full):
                ids.add(full)
    for sid in sorted(ids & set(allids)):
        print(sid)

elif CMD == "stats":
    c = conn()
    try:
        total = c.execute("select count(*) from sessions where " + SOURCE_SQL).fetchone()[0]
        msgs = c.execute("select count(*) from messages where session_id in (select id from sessions where " + SOURCE_SQL + ")").fetchone()[0]
        pinned = c.execute("select count(*) from sessions where " + SOURCE_SQL + " and pinned = 1").fetchone()[0]
        archived = c.execute("select count(*) from sessions where " + SOURCE_SQL + " and archived = 1").fetchone()[0]
        tok = c.execute("select coalesce(sum(input_tokens),0), coalesce(sum(output_tokens),0),"
                        " coalesce(sum(estimated_cost_usd),0) from sessions where " + SOURCE_SQL).fetchone()
        span = c.execute("select min(started_at), max(%s) from sessions where %s" % (SEEN_EXPR, SOURCE_SQL)).fetchone()
        per = c.execute("select source, count(*) n, coalesce(sum(message_count),0) m"
                        " from sessions where " + SOURCE_SQL + " group by 1 order by n desc").fetchall()
        top = c.execute("select id, " + TITLE_EXPR + " as title, message_count from sessions"
                        " where " + SOURCE_SQL + " order by coalesce(message_count,0) desc limit 5").fetchall()
        biggest = c.execute("select coalesce(sum(length(content)),0) from messages where session_id in (select id from sessions where " + SOURCE_SQL + ")").fetchone()[0]
    finally:
        c.close()
    print("会话总数   : %d（置顶 %d / 已归档 %d）" % (total, pinned, archived))
    print("消息总数   : %d" % msgs)
    print("Token 合计 : 输入 %s / 输出 %s" % (humantok(tok[0]), humantok(tok[1])))
    print("费用合计   : $%.4f" % tok[2])
    print("时间跨度   : %s → %s" % (stamp(span[0]), stamp(span[1])))
    print("正文体积   : %s" % humansize(biggest))
    db_size = os.path.getsize(DB_PATH) if os.path.exists(DB_PATH) else 0
    wal = DB_PATH + "-wal"
    wal_size = os.path.getsize(wal) if os.path.exists(wal) else 0
    print("数据库     : %s（WAL %s）" % (humansize(db_size), humansize(wal_size)))
    print()
    print("按来源统计：")
    for r in per:
        print("  %-10s %4d 个会话  %6d 条消息" % (r["source"], r["n"], r["m"]))
    print()
    print("消息最多的会话：")
    for n, r in enumerate(top, 1):
        print("  %d. %-8s %s" % (n, short_id(r["id"]), clip(r["title"] or "（未命名）", 52)))
PY_HELPER

# ---------- 通用 ----------
resolve_id() { "$PY" "$HELPER" "$STATE_DB" resolve "$1"; }

load_protected() {
  PROTECTED_CSV=$("$PY" "$HELPER" "$STATE_DB" active | paste -sd, -)
  export PROTECTED_IDS="$PROTECTED_CSV"
}

is_protected() {
  local id=$1 p
  [[ -z "$PROTECTED_CSV" ]] && return 1
  IFS=',' read -r -a arr <<< "$PROTECTED_CSV"
  for p in "${arr[@]}"; do
    [[ "$p" == "$id" ]] && return 0
  done
  return 1
}

confirm() {
  local ans
  read -r -p "$1 [y/N] " ans || return 1
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<'EOF'
用法: manage-hermes-sessions.sh [子命令] [参数]

不带参数进入交互菜单。子命令：

  list [-n N] [--source 来源] [--all]   列出会话（默认最近 20 条；--all 含归档/隐藏）
  search 关键词                          在标题和消息正文里搜索
  show <编号前缀|ID>                     查看会话详情（首尾消息、Token、费用、目录）
  rename <前缀|ID> 新标题                修改会话标题
  pin <前缀|ID...>                       置顶（免于自动归档）
  unpin <前缀|ID...>                     取消置顶
  export <前缀|ID|all> [md|jsonl] [目录] 导出会话（默认 md 到 ~/.hermes/session-exports）
  archive [天数] [-y]                    归档 N 天前的会话（软隐藏，不删除）
  delete [-y] <前缀|ID...>               删除指定会话（需要确认）
  prune [天数] [-y]                      删除 N 天前的会话（先干跑预览）
  stats                                  会话/消息/Token/费用/体积统计

  help                                   显示本帮助

范围：仅本地（local/cli/tui）和 QQ（qqbot），不管理 cron / subagent。
数据库：~/.hermes/state.db（或 $HERMES_HOME/state.db）；
可用环境变量 HERMES_SESSIONS_DB 指向别的库，HERMES_HOME 指向别的实例。
EOF
}

# ---------- 子命令实现 ----------
cmd_list() {
  "$PY" "$HELPER" "$STATE_DB" list "$@"
}

cmd_search() {
  [[ $# -ge 1 ]] || die "用法: search 关键词"
  "$PY" "$HELPER" "$STATE_DB" search "$1"
}

cmd_show() {
  [[ $# -ge 1 ]] || die "用法: show <前缀|ID>"
  local id
  id=$(resolve_id "$1") || exit 2
  "$PY" "$HELPER" "$STATE_DB" show "$id"
}

cmd_rename() {
  [[ $# -ge 2 ]] || die "用法: rename <前缀|ID> 新标题"
  local needle=$1 id
  shift
  id=$(resolve_id "$needle") || exit 2
  "$HERMES_BIN" sessions rename "$id" "$*"
}

cmd_pin_toggle() {
  local mode=$1
  shift
  [[ $# -ge 1 ]] || die "用法: $mode <前缀|ID...>"
  local needle id
  for needle in "$@"; do
    id=$(resolve_id "$needle") || continue
    "$HERMES_BIN" sessions "$mode" "$id"
  done
}

cmd_export() {
  local target=${1:-all} format=${2:-md} out=${3:-}
  case "$format" in
    md|jsonl|qmd) ;;
    *) die "导出格式只支持 md / jsonl / qmd" ;;
  esac
  if [[ -z "$out" ]]; then
    out="$HERMES_HOME_DIR/session-exports"
    [[ "$format" != "md" ]] && out="$HERMES_HOME_DIR/session-exports"
  fi
  mkdir -p "$out"
  if [[ "$target" == "all" ]]; then
    local src dest
    for src in local cli tui qqbot; do
      if [[ "$format" == "md" || "$format" == "qmd" ]]; then
        dest="$out/$src/"
        mkdir -p "$dest"
      else
        dest="$out/hermes-sessions-$(date +%Y%m%d-%H%M%S)-$src.$format"
      fi
      "$HERMES_BIN" sessions export --format "$format" --source "$src" --yes "$dest"
    done
  else
    local id
    id=$(resolve_id "$target") || exit 2
    if [[ "$format" == "md" ]]; then
      "$HERMES_BIN" sessions export --format md --session-id "$id" --yes "$out"
    else
      local file
      file="$out/$(date +%Y%m%d-%H%M%S)-${id##*-}.$format"
      "$HERMES_BIN" sessions export --format "$format" --session-id "$id" --yes "$file"
      printf '已写入：%s\n' "$file"
    fi
  fi
}

cmd_archive() {
  local days=${1:-30} assume_yes=0
  case "${2:-}" in -y|--yes) assume_yes=1 ;; esac
  [[ "$days" =~ ^[0-9]+$ ]] || die "天数必须是数字"
  printf '预览：归档 %s 天前的会话（不删除）\n\n' "$days"
  for src in local cli tui qqbot; do "$HERMES_BIN" sessions archive --source "$src" --older-than "$days" --dry-run; done
  printf '\n'
  if ((assume_yes == 0)); then
    confirm "确认归档以上会话？" || { printf '已取消。\n'; return 0; }
  fi
  for src in local cli tui qqbot; do "$HERMES_BIN" sessions archive --source "$src" --older-than "$days" --yes; done
  printf '已归档（可在大列表里用 list --all 看到）。\n'
}

cmd_prune() {
  local days=${1:-30} assume_yes=0
  case "${2:-}" in -y|--yes) assume_yes=1 ;; esac
  [[ "$days" =~ ^[0-9]+$ ]] || die "天数必须是数字"
  printf '预览：删除 %s 天前的会话（置顶/归档默认不动）\n\n' "$days"
  for src in local cli tui qqbot; do "$HERMES_BIN" sessions prune --source "$src" --older-than "$days" --dry-run; done
  printf '\n'
  if ((assume_yes == 0)); then
    confirm "确认永久删除以上会话？" || { printf '已取消。\n'; return 0; }
  fi
  for src in local cli tui qqbot; do "$HERMES_BIN" sessions prune --source "$src" --older-than "$days" --yes; done
  printf '\n已删除。\n'
}

cmd_delete() {
  local assume_yes=0 args=() a
  for a in "$@"; do
    case "$a" in
      -y|--yes) assume_yes=1 ;;
      *) args+=("$a") ;;
    esac
  done
  ((${#args[@]} > 0)) || die "用法: delete [-y] <前缀|ID...>"
  load_protected
  local ids=() needle id
  for needle in "${args[@]}"; do
    id=$(resolve_id "$needle") || exit 2
    if is_protected "$id"; then
      printf '跳过 %s：这是正在运行的会话，不能删除。\n' "$id"
      continue
    fi
    ids+=("$id")
  done
  ((${#ids[@]} > 0)) || { printf '没有可删除的会话。\n'; return 0; }
  printf '将删除：\n'
  for id in "${ids[@]}"; do
    "$PY" "$HELPER" "$STATE_DB" show "$id" | sed -n '1,2p' | sed 's/^/  /'
  done
  if ((assume_yes == 0)); then
    confirm "确认删除以上 ${#ids[@]} 个会话？" || { printf '已取消，未做任何更改。\n'; return 0; }
  fi
  for id in "${ids[@]}"; do
    "$HERMES_BIN" sessions delete --yes "$id"
  done
  printf '完成。\n'
}

# ---------- 交互：批量删除 ----------
batch_delete() {
  load_protected
  "$PY" "$HELPER" "$STATE_DB" tsv > "$WORK/list.tsv"
  local -a IDS=() LABELS=()
  local n id src msgs when title mk
  while IFS=$'\t' read -r n id src msgs when title mk; do
    IDS+=("$id")
    LABELS+=("#$n [$src] ${msgs}条 ${when} ${title}${mk:+  ★$mk}")
  done < "$WORK/list.tsv"
  if ((${#IDS[@]} == 0)); then
    printf '没有可管理的会话。\n'
    return 0
  fi

  printf '\n会话列表（★=置顶，“运行中”=当前活动会话，均受保护）：\n'
  cmd_list --limit 0

  local -A selected=()
  local menu=("${LABELS[@]}" "执行删除" "退出")
  local PS3='输入编号（可重复选择加入/取消）：'
  local choice REPLY
  set +u
  select choice in "${menu[@]}"; do
    if [[ -z "$REPLY" ]]; then
      printf '\n输入已结束，取消操作。\n'
      return 0
    fi
    if [[ ! "$REPLY" =~ ^[0-9]+$ ]] || ((REPLY < 1 || REPLY > ${#menu[@]})); then
      printf '无效编号「%s」，请重新选择。\n' "$choice"
      continue
    fi
    if ((REPLY == ${#menu[@]})); then
      printf '已取消。\n'
      return 0
    fi
    if ((REPLY == ${#menu[@]} - 1)); then
      break
    fi
    id=${IDS[$((REPLY - 1))]}
    if is_protected "$id"; then
      printf '会话 %s 正在运行中，不能删除。\n' "$id"
    elif [[ -n "${selected[$id]:-}" ]]; then
      unset 'selected[$id]'
      printf '已取消选择：%s\n' "${LABELS[$((REPLY - 1))]}"
    else
      selected["$id"]=1
      printf '已选择：%s\n' "${LABELS[$((REPLY - 1))]}"
    fi
    printf '当前已选：\n'
    local has=0 i
    for i in "${!IDS[@]}"; do
      if [[ -n "${selected[${IDS[$i]}]:-}" ]]; then
        printf '  %s\n' "${LABELS[$i]}"
        has=1
      fi
    done
    ((has == 1)) || printf '  （空）\n'
  done
  set -u

  local chosen=() i
  for i in "${!IDS[@]}"; do
    if [[ -n "${selected[${IDS[$i]}]:-}" ]]; then
      chosen+=("${IDS[$i]}")
    fi
  done
  if ((${#chosen[@]} == 0)); then
    printf '没有选择要删除的会话，未做任何更改。\n'
    return 0
  fi

  printf '\n最终选择删除：\n'
  for id in "${chosen[@]}"; do
    for i in "${!IDS[@]}"; do
      [[ "${IDS[$i]}" == "$id" ]] && printf '  %s\n' "${LABELS[$i]}"
    done
  done
  confirm "确认永久删除以上 ${#chosen[@]} 个会话？" || { printf '已取消，未做任何更改。\n'; return 0; }

  for id in "${chosen[@]}"; do
    "$HERMES_BIN" sessions delete --yes "$id"
  done
  printf '\n已删除所选会话。\n'

}

# ---------- 交互菜单 ----------
interactive() {
  load_protected
  local choice PS3='请选择操作：'
  while true; do
    local menu=(
      "列出最近会话"
      "搜索会话"
      "查看会话详情"
      "重命名会话"
      "置顶 / 取消置顶"
      "导出会话"
      "归档旧会话"
      "删除会话（勾选）"
      "清理 N 天前的会话"
      "会话统计"
      "退出"
    )
    printf '\n'
    local picked=0
    select choice in "${menu[@]}"; do
      if [[ -z "$REPLY" ]]; then
        break
      fi
      if [[ ! "$REPLY" =~ ^[0-9]+$ ]] || ((REPLY < 1 || REPLY > ${#menu[@]})); then
        printf '无效编号「%s」，请重新选择。\n' "$choice"
        continue
      fi
      picked=1
      break
    done
    if ((picked == 0)); then
      printf '输入已结束，退出。\n'
      return 0
    fi
    case $REPLY in
      1)
        printf '\n'
        read -r -p '来源筛选（回车=全部，仅 local/cli/tui/qqbot）：' src || src=''
        if [[ -n "$src" ]]; then cmd_list --limit 30 --source "$src"; else cmd_list --limit 20; fi
        printf '\n提示：全部会话（含归档）用 --all。\n'
        ;;
      2)
        local kw
        read -r -p '关键词：' kw || kw=''
        if [[ -n "$kw" ]]; then printf '\n'; cmd_search "$kw"; else printf '未输入关键词。\n'; fi
        ;;
      3)
        local needle
        read -r -p '会话编号前缀或 ID：' needle || needle=''
        if [[ -n "$needle" ]]; then printf '\n'; cmd_show "$needle" || true; fi
        ;;
      4)
        local needle title
        read -r -p '会话编号前缀或 ID：' needle || needle=''
        read -r -p '新标题：' title || title=''
        if [[ -n "$needle" && -n "$title" ]]; then cmd_rename "$needle" "$title"; else printf '已取消。\n'; fi
        ;;
      5)
        local needle act
        read -r -p '会话编号前缀或 ID：' needle || needle=''
        read -r -p '操作 [p=置顶/u=取消置顶]：' act || act=''
        case "$act" in
          p|P) cmd_pin_toggle pin "$needle" ;;
          u|U) cmd_pin_toggle unpin "$needle" ;;
          *) printf '已取消。\n' ;;
        esac
        ;;
      6)
        local target fmt out
        read -r -p '导出哪个会话（前缀/ID/all）：' target || target=''
        read -r -p '格式 [md/jsonl，默认 md]：' fmt || fmt=''
        fmt=${fmt:-md}
        read -r -p "输出目录 [默认 $HERMES_HOME_DIR/session-exports]：" out || out=''
        cmd_export "${target:-all}" "$fmt" "$out"
        ;;
      7)
        local days
        read -r -p '归档多少天前的会话 [默认 30]：' days || days=''
        cmd_archive "${days:-30}"
        ;;
      8)
        batch_delete
        ;;
      9)
        local days
        read -r -p '删除多少天前的会话 [默认 30]：' days || days=''
        cmd_prune "${days:-30}"
        ;;
      10)
        printf '\n'
        "$PY" "$HELPER" "$STATE_DB" stats
        printf '\n'

        ;;
      11)
        printf '已退出。\n'
        return 0
        ;;
    esac
  done
}

# ---------- 入口 ----------
sub=${1:-}
case "$sub" in
  "") interactive ;;
  help|-h|--help) usage ;;
  list) shift; cmd_list "$@" ;;
  search) shift; cmd_search "$@" ;;
  show|info) shift; cmd_show "$@" ;;
  rename) shift; cmd_rename "$@" ;;
  pin) cmd_pin_toggle pin "${@:2}" ;;
  unpin) cmd_pin_toggle unpin "${@:2}" ;;
  export) shift; cmd_export "$@" ;;
  archive) shift; cmd_archive "$@" ;;
  delete|rm) shift; cmd_delete "$@" ;;
  prune) shift; cmd_prune "$@" ;;
  stats) "$PY" "$HELPER" "$STATE_DB" stats ;;
  optimize) die "数据库整体优化不属于本地和 QQ 对话管理范围。" ;;
  browse) die "官方浏览器不限定来源，已停用；请使用 list。" ;;
  *) die "未知子命令：$sub（用 help 查看用法）" ;;
esac
