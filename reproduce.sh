#!/usr/bin/env bash
#
# Reproduces: an unrelated `credentials[]` entry flips the anthropic credential to
# api-key mode on the built-in `claude` agent. See README.md.
#
# Run on the host (needs `sbx`) with an anthropic OAuth credential configured, so the
# control case comes up in SBX_CRED_ANTHROPIC_MODE=none.
#
# The bug reproduces only when the unrelated credential actually RESOLVES to a value
# (a declared-but-unset credential does not trigger it), so this script stores a
# throwaway secret for `example-service` before case 3 and removes it on exit. The
# value is irrelevant — the trigger is that the credential resolves, not its contents.

set -u
cd "$(dirname "$0")"

W="$(mktemp -d)"
NAMES="repro-control repro-empty repro-credential"

cleanup() {
  for n in $NAMES; do sbx rm "$n" --force >/dev/null 2>&1 || true; done
  sbx secret rm -g example-service --force >/dev/null 2>&1 || true
  rmdir "$W" 2>/dev/null || true
}
trap cleanup EXIT

# Give the unrelated credential a value so it resolves (see note above).
sbx secret set -g example-service -t dummy

# Prints the anthropic mode and whether the apiKeyHelper was seeded.
PROBE='echo "MODE=${SBX_CRED_ANTHROPIC_MODE:-unset}"; \
[ -f "$HOME/.claude/.credentials.json" ] && echo oauth_creds=present || echo oauth_creds=absent; \
grep -o "\"apiKeyHelper\"[^,}]*" "$HOME/.claude/settings.json" 2>/dev/null || echo apiKeyHelper=absent'

run_case() {  # $1=name  $2=label  rest=extra `sbx create` args
  name="$1"; label="$2"; shift 2
  echo "=================== ${label} ==================="
  sbx create claude "$@" --name "$name" "$W"
  sbx exec "$name" -- sh -c "$PROBE"
  echo
}

run_case repro-control    "control (no kit)"
run_case repro-empty      "empty mixin"               --kit ./mixin-empty/
run_case repro-credential "mixin with one credential" --kit ./mixin-with-credential/

echo "Expected: all three MODE=none, apiKeyHelper=absent."
echo "Actual:   case 3 shows MODE=apikey and apiKeyHelper present."
