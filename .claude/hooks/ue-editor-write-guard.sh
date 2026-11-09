#!/usr/bin/env bash
# PreToolUse hook for the ue-editor subagent (Write/Edit).
# Allows writes only inside .claude/agent-memory/ue-editor/. Anything else is blocked (exit 2).
# Reads the hook JSON from stdin. No jq needed.

input="$(cat)"

# tool_input.file_path. Escaped quotes inside other strings do not match this pattern.
path="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

if [ -z "$path" ]; then
  echo "ue-editor write guard: could not read file_path, so the write was blocked." >&2
  exit 2
fi

# Normalize: JSON-escaped backslashes and Windows backslashes become /, compare in lower case.
normalized="$(printf '%s' "$path" | sed 's/\\\\/\//g; s/\\/\//g' | tr '[:upper:]' '[:lower:]')"

case "$normalized" in
  */../*|*/..)
    ;;
  */.claude/agent-memory/ue-editor/*)
    exit 0
    ;;
esac

echo "ue-editor write guard: ue-editor may only write inside .claude/agent-memory/ue-editor/. Blocked: $path. Report what you needed to change instead." >&2
exit 2
