# agent-wrap

Run AI coding agents ([Gemini CLI](https://github.com/google-gemini/gemini-cli), [OpenCode](https://github.com/opencode-ai/opencode), [Antigravity](https://antigravity.google/), [Grok Build](https://x.ai/)) in a Docker sandbox against your current directory, with auto-approved tools and persistent session state.

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

**Requirements:** Docker. `GEMINI_API_KEY` for Gemini. `XAI_API_KEY` optional for Grok (otherwise browser OAuth).

## Usage

```bash
cd /path/to/project
aw gemini "refactor the auth module"
aw opencode
aw agy
aw grok "explain this codebase"
```

First arg is the agent (`gemini` | `opencode` | `agy` | `grok`); the rest is forwarded to that CLI.

| Agent       | Image                               | Notes                                       |
|-------------|-------------------------------------|---------------------------------------------|
| `gemini`    | `docker/sandbox-templates:gemini`   | needs `GEMINI_API_KEY`, runs with `--yolo`  |
| `opencode`  | `docker/sandbox-templates:opencode` | `OPENCODE_YOLO=1`                           |
| `agy`       | `custom-sandbox:antigravity`        | build from `antigravity/`                   |
| `grok`      | `custom-sandbox:grok`               | auto-built on first run; `--always-approve` |

The cwd is mounted read/write at `/workspace`. Auth/settings live in `~/.${agent}-cli-state` on the host.

## Security

YOLO / always-approve means no tool confirmations. Full network egress. Only use on workspaces you trust.
