#!/bin/bash
# agent-wrap (aw) - A strict execution wrapper for AI agents

AGENT=$1
# Allow "oc" as a shorthand for "opencode"
if [ "$AGENT" = "oc" ]; then
    AGENT="opencode"
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
if [[ "$AGENT" != "opencode" && "$AGENT" != "agy" && "$AGENT" != "grok" ]]; then
    echo "❌ Error: First argument must be 'opencode', 'agy' or 'grok'."
    echo "Usage: aw <opencode|agy|grok> [additional args]"
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
fi

# Append $RANDOM to guarantee a unique container name for every instance
CONTAINER_NAME="${AGENT}-yolo-$(basename "$WORKSPACE")-$RANDOM"

# 5. Execute the Sandbox
# - --workdir: Drops the agent exactly where you are
# - :rw gives write access ONLY to the current directory
# - osc52pty (when installed) intercepts OSC 52 clipboard escapes emitted by
#   the agent and pipes them into macOS's pbcopy, making copy work even on
#   Terminal.app (which does not support OSC 52 natively).
RUN_CMD=(docker run -it --rm \
  --name "$CONTAINER_NAME" \
  -e TERM="$TERM" \
  --workdir /workspace \
  -v "$WORKSPACE:/workspace:rw" \
  -v "$MEMORY_DIR:$TARGET_MOUNT" \
  $YOLO_ENV \
  $CONFIG_MOUNT \
  $STATE_MOUNT \
  $IMAGE_REF $AGENT $FLAGS "$@")

if command -v osc52pty >/dev/null 2>&1; then
    RUN_CMD=(osc52pty "${RUN_CMD[@]}")
else
    echo "Tip: build osc52pty (the @latest release segfaults on modern macOS; this patch is required) to enable clipboard copy from the sandbox on Terminal.app:"
    echo "  git clone https://github.com/roy2220/osc52pty && cd osc52pty"
    echo "  sed -i '' 's|golang.org/x/crypto v0.0.0-20200820211705-5c72a883971a|golang.org/x/term v0.30.0|' go.mod"
    echo "  sed -i '' 's|\"golang.org/x/crypto/ssh/terminal\"|\"golang.org/x/term\"|; s|terminal\\.MakeRaw|term.MakeRaw|g; s|terminal\\.Restore|term.Restore|g' shell.go"
    echo "  go get github.com/creack/pty@latest && go mod tidy"
    echo "  go install .   # -> ~/go/bin/osc52pty"
    echo "  export PATH=\"\$PATH:\$HOME/go/bin\"   # add to ~/.bash_profile if missing"
fi

"${RUN_CMD[@]}"
