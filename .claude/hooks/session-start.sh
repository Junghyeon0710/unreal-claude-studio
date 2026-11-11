#!/usr/bin/env bash
# SessionStart hook: show where the project stands when a session starts and after compaction.
# Prints plain text. Claude Code adds a SessionStart hook's stdout to Claude's context (not shown in chat).
# Reads: docs/tasks/*.md (cards in progress), docs/progress.md ("다음 할 일"), git status.
# Always exits 0: a missing file or folder just leaves its part out.

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0

# Nothing to show in a project without the studio's docs.
[ -d docs/tasks ] || [ -f docs/progress.md ] || exit 0

# The hook input is one JSON line. Read one line at most and do not wait long for it.
source=""
if IFS= read -r -t 1 input; then
  source="$(printf '%s' "$input" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p')"
fi

echo "[진행 상황: 대화 시작 훅이 docs/tasks/, docs/progress.md, git status에서 읽은 요약]"
if [ "$source" = "compact" ]; then
  echo "대화가 요약됐다. 하던 일은 기억 대신 카드의 진행 기록과 git status를 보고 이어서 한다."
fi

# Cards in progress, and the waiting ones.
if [ -d docs/tasks ]; then
  active=""
  waiting=0
  next_waiting=""
  for card in docs/tasks/[0-9]*.md; do
    [ -f "$card" ] || continue
    status="$(sed -n 's/^- 상태:[[:space:]]*//p' "$card" | head -n 1 | sed 's/[[:space:]]*$//')"
    case "$status" in
      "진행 중"|"검토 중")
        title="$(head -n 1 "$card" | sed 's/^#[[:space:]]*//')"
        last="$(grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2}:' "$card" | tail -n 1 | sed 's/^- //')"
        active="${active}- ${title} (${status}) — ${card}"$'\n'"  마지막 기록: ${last:-없음}"$'\n'
        ;;
      "대기")
        waiting=$((waiting + 1))
        [ -z "$next_waiting" ] && next_waiting="$card"
        ;;
    esac
  done
  echo
  if [ -n "$active" ]; then
    echo "진행 중인 카드 (/work로 이어서 한다):"
    printf '%s' "$active"
  else
    echo "진행 중인 카드: 없음"
  fi
  if [ "$waiting" -gt 0 ]; then
    echo "대기 카드: ${waiting}장 (번호가 가장 작은 것: ${next_waiting})"
  fi
fi

# Next steps from the progress log.
if [ -f docs/progress.md ]; then
  echo
  echo "다음 할 일 (docs/progress.md, 자세한 기록은 같은 파일의 \"지금 상태\"):"
  awk '/^## 다음 할 일/ { on = 1; next } /^## / { on = 0 } on && NF' docs/progress.md | head -n 20
fi

# Uncommitted work.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(git branch --show-current 2>/dev/null)"
  changes="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo
  echo "Git: 브랜치 ${branch:-알 수 없음}, 커밋 안 한 변경 ${changes}개"
fi

exit 0
