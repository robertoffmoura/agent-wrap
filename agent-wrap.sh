#!/bin/bash
# agent-wrap (aw) - A strict execution wrapper for AI agents

AGENT=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

echo "Starting $AGENT in YOLO mode..."
echo "✅ Workspace (Read/Write): $WORKSPACE"
echo "⚠️ Network: Full Egress (Proxy filtering not yet applied)"

# 4. Set Agent-Specific YOLO Environment Variables
if [ "$AGENT" = "agy" ]; then
    IMAGE_REF="custom-sandbox:antigravity"
    TARGET_MOUNT="/home/agent/.gemini"
elif [ "$AGENT" = "grok" ]; then
    # No official docker/sandbox-templates:grok image — use a custom build
    # (same approach as antigravity).
    IMAGE_REF="custom-sandbox:grok"
    if ! docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
        echo "Building custom Grok sandbox image (first run)..."
        docker build -t "$IMAGE_REF" "$SCRIPT_DIR/grok"
    fi

    # Prefer XAI_API_KEY when set; otherwise Grok falls back to browser OAuth
    # (same pattern as antigravity — auth tokens land in the mounted state dir).
    if [ -n "$XAI_API_KEY" ]; then
        YOLO_ENV="-e XAI_API_KEY=$XAI_API_KEY"
    fi
    # Auto-approve tools
    FLAGS="--always-approve"
elif [ "$AGENT" = "opencode" ]; then
    YOLO_ENV="-e OPENCODE_YOLO=1"
    if [ -f "$HOME/.config/opencode/opencode.json" ]; then
        CONFIG_MOUNT="-v $HOME/.config/opencode/opencode.json:/home/agent/.config/opencode/opencode.json:ro"
    fi
fi

# Append $RANDOM to guarantee a unique container name for every instance
CONTAINER_NAME="${AGENT}-yolo-$(basename "$WORKSPACE")-$RANDOM"

# 5. Execute the Sandbox
# - --workdir: Drops the agent exactly where you are
# - :rw gives write access ONLY to the current directory
docker run -it --rm \
  --name "$CONTAINER_NAME" \
  -e TERM="$TERM" \
  --workdir /workspace \
  -v "$WORKSPACE:/workspace:rw" \
  -v "$MEMORY_DIR:$TARGET_MOUNT" \
  $YOLO_ENV \
  $CONFIG_MOUNT \
  $IMAGE_REF $AGENT $FLAGS "$@"
