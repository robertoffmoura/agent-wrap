#!/bin/bash
# agent-wrap (aw) - A strict execution wrapper for AI agents

AGENT=$1
# Allow "oc" as a shorthand for "opencode"
if [ "$AGENT" = "oc" ]; then
    AGENT="opencode"
fi
# Allow "cc" as a shorthand for "claude"
if [ "$AGENT" = "cc" ]; then
    AGENT="claude"
fi
# Resolve symlinks so SCRIPT_DIR points at the repo, not the dir containing the
# `aw` symlink (e.g. /usr/local/bin/aw -> .../agent-wrap.sh). Needed to locate
# the Dockerfile dirs (opencode/, grok/, antigravity/).
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Ensure OrbStack (Docker engine) is running
if ! orb status >/dev/null 2>&1; then
    echo "Starting OrbStack..."
    orb start
fi

# 1. Verify the Agent Argument
if [[ "$AGENT" != "opencode" && "$AGENT" != "agy" && "$AGENT" != "grok" && "$AGENT" != "claude" ]]; then
    echo "❌ Error: First argument must be 'opencode', 'agy', 'grok' or 'claude'."
    echo "Usage: aw <opencode|agy|grok|claude> [additional args]"
    exit 1
fi

# Shift the arguments so "$@" now only contains the prompt/flags you want to pass to the agent
shift

# 2. Get the current directory (Workspace)
WORKSPACE=$(pwd)

# 3. This folder stores all the UUID sessions permanently on your Mac
MEMORY_DIR="$HOME/.${AGENT}-cli-state"
mkdir -p "$MEMORY_DIR"
TARGET_MOUNT="/home/agent/.$AGENT"
FLAGS=""
IMAGE_REF="docker/sandbox-templates:$AGENT"
YOLO_ENV=""
CONFIG_MOUNT=""
STATE_MOUNT=""

echo "Starting $AGENT in YOLO mode..."
echo "✅ Workspace (Read/Write): $WORKSPACE"
echo "⚠️ Network: Full Egress (Proxy filtering not yet applied)"

# 4. Set Agent-Specific YOLO Environment Variables
# Build a custom sandbox image on first run if it doesn't exist locally.
build_image_if_missing() {
    local image_ref="$1" build_dir="$2" label="$3"
    if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
        echo "Building custom $label sandbox image (first run)..."
        docker build -t "$image_ref" "$build_dir"
    fi
}

if [ "$AGENT" = "agy" ]; then
    IMAGE_REF="custom-sandbox:antigravity"
    TARGET_MOUNT="/home/agent/.gemini"
    build_image_if_missing "$IMAGE_REF" "$SCRIPT_DIR/antigravity" "Antigravity"
elif [ "$AGENT" = "grok" ]; then
    # No official docker/sandbox-templates:grok image — use a custom build.
    IMAGE_REF="custom-sandbox:grok"
    build_image_if_missing "$IMAGE_REF" "$SCRIPT_DIR/grok" "Grok"

    # Prefer XAI_API_KEY when set; otherwise Grok falls back to browser OAuth
    # (same pattern as antigravity — auth tokens land in the mounted state dir).
    if [ -n "$XAI_API_KEY" ]; then
        YOLO_ENV="-e XAI_API_KEY=$XAI_API_KEY"
    fi
    # Auto-approve tools
    FLAGS="--always-approve"
elif [ "$AGENT" = "opencode" ]; then
    # Custom build installs the latest opencode at build time.
    IMAGE_REF="custom-sandbox:opencode"
    build_image_if_missing "$IMAGE_REF" "$SCRIPT_DIR/opencode" "OpenCode"

    # Auto-approve permissions (--auto; --yolo is a hidden alias).
    FLAGS="--auto"
    TARGET_MOUNT="/home/agent/.local/share/opencode"
    # Persist the model/variant selection (model.json) across containers.
    mkdir -p "$HOME/.local/state/opencode"
    STATE_MOUNT="-v $HOME/.local/state/opencode:/home/agent/.local/state/opencode"
    if [ -n "$DEEPSEEK_API_KEY" ]; then
        YOLO_ENV="$YOLO_ENV -e DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY"
    fi
    if [ -f "$HOME/.config/opencode/opencode.json" ]; then
        CONFIG_MOUNT="-v $HOME/.config/opencode/opencode.json:/home/agent/.config/opencode/opencode.json:ro"
    fi
elif [ "$AGENT" = "claude" ]; then
    # No official docker/sandbox-templates:claude image — use a custom build.
    IMAGE_REF="custom-sandbox:claude"
    build_image_if_missing "$IMAGE_REF" "$SCRIPT_DIR/claude" "Claude Code"

    # Auto-approve tools
    FLAGS="--dangerously-skip-permissions"

    # Prefer ANTHROPIC_API_KEY when set; otherwise Claude Code falls back to
    # browser/Console OAuth (same pattern as grok — auth tokens land in the
    # mounted state dir at ~/.claude/.credentials.json).
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        YOLO_ENV="-e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
    fi

    # ~/.claude.json (onboarding/project state) lives outside ~/.claude, so
    # it needs its own mount to persist across containers. Claude Code treats
    # an empty file as corrupted JSON, so seed it with an empty object.
    if [ ! -s "$MEMORY_DIR.json" ]; then
        echo '{}' > "$MEMORY_DIR.json"
    fi
    CONFIG_MOUNT="-v $MEMORY_DIR.json:/home/agent/.claude.json"
fi

# Append $RANDOM to guarantee a unique container name for every instance
CONTAINER_NAME="${AGENT}-yolo-$(basename "$WORKSPACE")-$RANDOM"

# Per-container dir where osc52pty saves the clipboard image on each
# Ctrl+V; mounted read-only for the xclip/wl-paste shims in the image.
CLIPBOARD_DIR="$HOME/.agent-wrap/clipboard/$CONTAINER_NAME"
mkdir -p "$CLIPBOARD_DIR"
trap 'rm -f "$CLIPBOARD_DIR/clip.png" "$CLIPBOARD_DIR/.clip.png.tmp"; rmdir "$CLIPBOARD_DIR" 2>/dev/null' EXIT

# 5. Execute the Sandbox
# - --workdir: Drops the agent exactly where you are
# - :rw gives write access ONLY to the current directory
# - osc52pty (when installed; source in osc52pty/) intercepts OSC 52
#   clipboard escapes emitted by the agent and pipes them into macOS's
#   pbcopy, making copy work even on Terminal.app (which does not support
#   OSC 52 natively). It also saves the clipboard image to $CLIPBOARD_DIR on
#   each Ctrl+V, so image paste works in the sandbox.
RUN_CMD=(docker run -it --rm \
  --name "$CONTAINER_NAME" \
  -e TERM="$TERM" \
  --workdir /workspace \
  -v "$WORKSPACE:/workspace:rw" \
  -v "$MEMORY_DIR:$TARGET_MOUNT" \
  -v "$CLIPBOARD_DIR:/run/host-clipboard:ro" \
  $YOLO_ENV \
  $CONFIG_MOUNT \
  $STATE_MOUNT \
  $IMAGE_REF $AGENT $FLAGS "$@")

OSC52PTY_PATH="$(command -v osc52pty)"
if [ -n "$OSC52PTY_PATH" ]; then
    RUN_CMD=(env OSC52PTY_CLIPBOARD_DIR="$CLIPBOARD_DIR" osc52pty "${RUN_CMD[@]}")
fi
# Our build embeds the env var name; its absence means an upstream/old build.
if [ -z "$OSC52PTY_PATH" ] || ! grep -q OSC52PTY_CLIPBOARD_DIR "$OSC52PTY_PATH"; then
    if [ -n "$OSC52PTY_PATH" ]; then
        echo "⚠️ $OSC52PTY_PATH is not agent-wrap's build; reinstall it as below for Ctrl+V image paste."
    fi
    echo "Tip: install agent-wrap's osc52pty (requires Go) to enable clipboard copy and Ctrl+V image paste in the sandbox on Terminal.app:"
    echo "  cd \"$SCRIPT_DIR/osc52pty\" && go install .   # -> ~/go/bin/osc52pty"
    echo "  export PATH=\"\$PATH:\$HOME/go/bin\"   # add to ~/.bash_profile if missing"
fi

"${RUN_CMD[@]}"
