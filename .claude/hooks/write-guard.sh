#!/usr/bin/env bash
# PreToolUse hook for subagents (Write/Edit): allow writes only inside the given folders of this project.
# Usage in agent frontmatter: bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/write-guard.sh" <folder> [<folder> ...]
#   with onFailure: block, so a hook that cannot run blocks the write instead of allowing it.
#   Folders are relative to the project root and may use * (quote them), e.g. 'Source/*/Tests/'.
# Anything else, including paths outside the project, is blocked with exit 2.
# Reads the hook JSON from stdin. No jq needed.

block() {
  echo "write guard: this agent may only write inside these project folders: $ALLOWED. $1 Report what you needed to change instead." >&2
  exit 2
}

# Lower case, / separators, no trailing slash. Also undoes JSON-escaped backslashes.
normalize() {
  printf '%s' "$1" | sed 's/\\\\/\//g; s/\\/\//g; s://*:/:g; s:/*$::' | tr '[:upper:]' '[:lower:]'
}

ALLOWED="$*"
input="$(cat)"

# tool_input.file_path. Escaped quotes inside other strings do not match this pattern.
path="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
[ -z "$path" ] && block "Could not read file_path."

file="$(normalize "$path")"
case "$file" in
  */../*|*/..|../*) block "Paths with .. are not allowed: $path." ;;
esac

# Project root: CLAUDE_PROJECT_DIR, else the current folder (the hook command runs from the project root).
root="${CLAUDE_PROJECT_DIR:-}"
[ -z "$root" ] && root="$(pwd -W 2>/dev/null || pwd)"
root="$(normalize "$root")"
# A Git Bash style root (/d/...) is compared as d:/... when the file path is a Windows drive path.
case "$file" in
  [a-z]:/*) root="$(printf '%s' "$root" | sed 's#^/\([a-z]\)/#\1:/#')" ;;
esac

case "$file" in
  "$root"/*) relative="${file#"$root"/}" ;;
  *) block "Outside the project: $path." ;;
esac

for allowed in "$@"; do
  # Some shells pass the quotes around 'Source/*/Tests/' through; drop them.
  allowed="${allowed#[\'\"]}"
  allowed="${allowed%[\'\"]}"
  pattern="$(normalize "$allowed" | sed 's:^\./::; s:^/*::')"
  [ -z "$pattern" ] && continue
  # Unquoted on purpose so * in a folder pattern works.
  case "$relative" in
    $pattern/*) exit 0 ;;
  esac
done

block "Blocked: $path."
