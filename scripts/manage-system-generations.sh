#!/usr/bin/env bash
set -euo pipefail

profile=/nix/var/nix/profiles/system

if ! command -v nix-env >/dev/null 2>&1; then
  printf '错误：找不到 nix-env。\n' >&2
  exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
  printf '错误：找不到 sudo。请用 root 运行此脚本。\n' >&2
  exit 1
fi
if [[ ! -L "$profile" ]]; then
  printf '错误：系统 profile 不存在：%s\n' "$profile" >&2
  exit 1
fi

printf '读取系统 generations...\n'
listing=$(sudo nix-env --profile "$profile" --list-generations)
declare -A rows=()
current=''
ids=()
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]] ]]; then
    id=${BASH_REMATCH[1]}
    ids+=("$id")
    rows["$id"]=$line
    if [[ "$line" == *'(current)'* ]]; then
      current=$id
    fi
  fi
done <<< "$listing"

if [[ -z "$current" ]]; then
  printf '错误：无法从 nix-env 输出识别当前 generation；未做任何更改。\n' >&2
  printf '%s\n' "$listing"
  exit 1
fi

printf '\n系统 generations（当前代次受保护）：\n%s\n' "$listing"
printf '\n用菜单选择要删除的代次；可重复选择以加入/取消。\n'
declare -A selected=()
menu=()
for id in "${ids[@]}"; do
  menu+=("${rows[$id]}")
done
menu+=("执行删除" "退出")
PS3='输入菜单编号：'
select choice in "${menu[@]}"; do
  if [[ ! "$REPLY" =~ ^[0-9]+$ ]] || ((REPLY < 1 || REPLY > ${#menu[@]})); then
    printf '无效编号，请重新选择。\n'
    continue
  fi

  if ((REPLY == ${#ids[@]} + 2)); then
    printf '已取消。\n'
    exit 0
  fi
  if ((REPLY == ${#ids[@]} + 1)); then
    break
  fi

  id=${ids[$((REPLY - 1))]}
  if [[ "$id" == "$current" ]]; then
    printf 'generation %s 是当前系统，不能删除。\n' "$id"
  elif [[ -n "${selected[$id]+yes}" ]]; then
    unset 'selected[$id]'
    printf '已取消选择 generation %s。\n' "$id"
  else
    selected["$id"]=1
    printf '已选择 generation %s。\n' "$id"
  fi

  printf '当前已选：\n'
  has_selection=false
  for candidate in "${ids[@]}"; do
    if [[ -n "${selected[$candidate]+yes}" ]]; then
      printf '  %s\n' "${rows[$candidate]}"
      has_selection=true
    fi
  done
  if [[ "$has_selection" == false ]]; then
    printf '  （空）\n'
  fi
done

chosen=()
for id in "${ids[@]}"; do
  if [[ -n "${selected[$id]+yes}" ]]; then
    chosen+=("$id")
  fi
done
if ((${#chosen[@]} == 0)); then
  printf '没有选择要删除的代次，未做任何更改。\n'
  exit 0
fi

printf '\n最终选择删除：\n'
for id in "${chosen[@]}"; do
  printf '  %s\n' "${rows[$id]}"
done
printf '\n当前 generation %s 会保留；旧代次保留数量由你决定。\n' "$current"
read -r -p '确认删除以上 generations？[y/N] ' confirm
case "$confirm" in
  y|Y) ;;
  *) printf '已取消，未做任何更改。\n'; exit 0 ;;
esac

sudo nix-env --profile "$profile" --delete-generations "${chosen[@]}"
printf '\n已删除所选 generation 记录。\n'
read -r -p '现在回收不再被引用的 Nix store 路径？[y/N] ' collect
case "$collect" in
  y|Y) sudo nix-collect-garbage ;;
  *) printf '未运行垃圾回收；每周自动 GC 仍由 NixOS 配置执行。\n' ;;
esac
