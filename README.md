# agent-wrap

Run AI coding agents ([OpenCode](https://github.com/opencode-ai/opencode), [Antigravity](https://antigravity.google/), [Grok Build](https://x.ai/), [Claude Code](https://code.claude.com/)) in a Docker sandbox against your current directory, with auto-approved tools and persistent session state.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/robertoffmoura/agent-wrap/main/agent-wrap.sh \
  -o /usr/local/bin/aw
chmod +x /usr/local/bin/aw
```

Or clone and symlink:

```bash
git clone https://github.com/robertoffmoura/agent-wrap.git
ln -s "$(pwd)/agent-wrap/agent-wrap.sh" /usr/local/bin/aw
```

**Requirements:** Docker. `XAI_API_KEY` optional for Grok, `ANTHROPIC_API_KEY` optional for Claude (otherwise browser/Console OAuth).

## Usage

```bash
cd /path/to/project
aw opencode
aw agy
aw grok "explain this codebase"
aw claude
```

First arg is the agent (`opencode` | `agy` | `grok` | `claude`; `oc`/`cc` are shorthands for `opencode`/`claude`); the rest is forwarded to that CLI.

| Agent       | Image                               | Notes                                                     |
|-------------|-------------------------------------|------------------------------------------------------------|
| `opencode`  | `docker/sandbox-templates:opencode` | `OPENCODE_YOLO=1`                                          |
| `agy`       | `custom-sandbox:antigravity`        | build from `antigravity/`                                  |
| `grok`      | `custom-sandbox:grok`               | auto-built on first run; `--always-approve`                |
| `claude`    | `custom-sandbox:claude`             | auto-built on first run; `--dangerously-skip-permissions`  |

The cwd is mounted read/write at `/workspace`. Auth/settings live in `~/.${agent}-cli-state` on the host.

## Security

YOLO / always-approve means no tool confirmations. Full network egress. Only use on workspaces you trust.
