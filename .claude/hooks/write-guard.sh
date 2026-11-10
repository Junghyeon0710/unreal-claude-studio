#!/usr/bin/env bash
# PreToolUse hook for subagents (Write/Edit): allow writes only inside the folders given as arguments.
# Usage in agent frontmatter: bash .claude/hooks/write-guard.sh .claude/agent-memory/<agent>/ [more folders]
# Anything else is blocked with exit 2. Reads the hook JSON from stdin. No jq needed.

input="$(cat)"

# tool_input.file_path. Escaped quotes inside other strings do not match this pattern.
path="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

if [ -z "$path" ]; then
  echo "write guard: could not read file_path, so the write was blocked." >&2
  exit 2
fi

# Normalize: JSON-escaped backslashes and Windows backslashes become /, compare in lower case.
normalized="$(printf '%s' "$path" | sed 's/\\\\/\//g; s/\\/\//g' | tr '[:upper:]' '[:lower:]')"

case "$normalized" in
  */../*|*/..)
    echo "write guard: paths with .. are not allowed. Blocked: $path" >&2
    exit 2
    ;;
esac

for allowed in "$@"; do
  folder="$(printf '%s' "$allowed" | sed 's/\\/\//g; s:^\./::; s:^/*::; s:/*$::' | tr '[:upper:]' '[:lower:]')"
  [ -z "$folder" ] && continue
  case "$normalized" in
    */"$folder"/*) exit 0 ;;
  esac
done

echo "write guard: this agent may only write inside: $*. Blocked: $path. Report what you needed to change instead." >&2
exit 2
