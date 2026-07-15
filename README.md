# sbx: an unrelated `credentials[]` entry flips the anthropic credential to api-key mode

## Summary

On the built-in `claude` agent, composing a mixin that declares a `credentials[]` entry for **any**
service — where that credential **resolves to a value** — causes sbx to resolve the **anthropic**
credential as `apikey` (`SBX_CRED_ANTHROPIC_MODE=apikey`) instead of using the claude.ai OAuth bridge
(`SBX_CRED_ANTHROPIC_MODE=none`). A declared-but-unset credential does **not** trigger it; the
credential must actually resolve (from the secret store, an env var, or a file).

This makes the built-in agent seed `"apiKeyHelper": "echo proxy-managed"` into
`~/.claude/settings.json`. Claude Code ranks `apiKeyHelper` above the claude.ai OAuth login, so it
authenticates with the api-key sentinel and **disables all claude.ai-synced MCP connectors**. This is visible by the following message on a fresh session:

> claude.ai connectors are disabled because ANTHROPIC_API_KEY or another auth source is set

And `/mcp` will not show any MCP, whereas it is expected to list the claude.ai-synced connectors.

## Environment

- sbx version: `sbx version: v0.35.0 01e01520456e4126a9653471e7072e4d9b280321`
- Template / agent: built-in `claude` (`docker/sandbox-templates:claude-code-docker`)
- Host: macOS (also reproducible on Linux)

## Reproduce

From this repository's directory, on the host (needs `sbx`, with an anthropic OAuth credential
configured):

```sh
./reproduce.sh
```

It stores a throwaway secret for `example-service` (so the credential resolves), creates three
sandboxes on the built-in `claude` agent — no kit, an empty mixin, and `mixin-with-credential/` —
prints `SBX_CRED_ANTHROPIC_MODE` and whether `apiKeyHelper` was seeded for each, then removes the
sandboxes and the secret.

## Expected vs actual

**Expected:** anthropic's mode depends only on how *anthropic* is configured. All three cases should
stay `SBX_CRED_ANTHROPIC_MODE=none` (OAuth bridge), and no `apiKeyHelper` should be written, because
none of them configures an anthropic api-key credential.

**Actual:** the credential mixin flips anthropic to `apikey` and seeds `apiKeyHelper`:

| Case                         | `SBX_CRED_ANTHROPIC_MODE` | `apiKeyHelper` | `oauth_creds` |
|------------------------------|---------------------------|----------------|---------------|
| control (no kit)             | `none`                    | absent         | present       |
| empty mixin                  | `none`                    | absent         | present       |
| mixin with one credential    | **`apikey`**              | **present**    | present       |

## What is *not* the cause

- **Not composition itself** — the empty mixin stays `none`.
- **Not the mixin name** — the base agent name stays `claude` (this mixin is composed via `--kit`,
  not a renamed `kind: sandbox`). This is a different trigger from the name-dependent OAuth failure
  reported elsewhere.
- **Not the network policy** — the OAuth token endpoint is reachable (`forward`) in every case;
  `caps.network.allow` composes additively and is not involved (a network-only mixin also stays
  `none`).
