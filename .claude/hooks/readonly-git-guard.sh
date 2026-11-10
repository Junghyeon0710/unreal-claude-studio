#!/usr/bin/env bash
# PreToolUse hook for subagents (Bash): allow only single read-only git commands.
# Allowed: git [--no-pager] status | diff | log | show | ls-files | blame | rev-parse
# Blocked: anything else, chaining or redirection (; & | < > ` $ newline), and --output.
# Reads the hook JSON from stdin. No jq needed.

input="$(cat)"

# tool_input.command, keeping JSON escapes (\" \\ \n) so nothing hides behind an escaped quote.
command="$(printf '%s' "$input" | sed -n -E 's/.*"command"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' | head -n 1)"

block() {
  echo "read-only guard: only single read-only git commands are allowed (git status, diff, log, show, ls-files, blame, rev-parse), run from the project folder. $1" >&2
  exit 2
}

[ -z "$command" ] && block "Could not read the command."

case "$command" in
  *';'*|*'&'*|*'|'*|*'<'*|*'>'*|*'`'*|*'$'*|*'\n'*|*'\r'*)
    block "Chaining, redirection and substitution are not allowed."
    ;;
  *--output*)
    block "--output writes a file."
    ;;
esac

trimmed="$(printf '%s' "$command" | sed 's/^[[:space:]]*//')"
if printf '%s' "$trimmed" | grep -Eq '^git([[:space:]]+--no-pager)?[[:space:]]+(status|diff|log|show|ls-files|blame|rev-parse)([[:space:]]|$)'; then
  exit 0
fi

block "Blocked: $command"
