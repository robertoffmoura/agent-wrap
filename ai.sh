#!/bin/bash
# ai - A strict execution wrapper for AI agents

AGENT=$1

# 1. Verify the Agent Argument
if [[ "$AGENT" != "gemini" && "$AGENT" != "opencode" ]]; then
    echo "❌ Error: First argument must be 'gemini' or 'opencode'."
    echo "Usage: ai.sh <gemini|opencode> [additional args]"
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

echo "Starting $AGENT in YOLO mode..."
echo "✅ Workspace (Read/Write): $WORKSPACE"
echo "⚠️ Network: Full Egress (Proxy filtering not yet applied)"

# 4. Set Agent-Specific YOLO Environment Variables
if [ "$AGENT" = "gemini" ]; then
    # Ensure API Key is present for Gemini
    if [ -z "$GEMINI_API_KEY" ]; then
        echo "❌ Error: GEMINI_API_KEY environment variable is missing!"
        echo "Please set it in your ~/.bash_profile"
        exit 1
    fi

    # Pre-select the API key method to bypass the interactive prompt
    cat <<EOF > "$MEMORY_DIR/settings.json"
{
  "security": {
    "auth": {
      "selectedType": "gemini-api-key"
    }
  }
}
EOF

    YOLO_ENV="-e GEMINI_YOLO_MODE=true \
        -e GEMINI_API_KEY=$GEMINI_API_KEY \
        -e GEMINI_CLI_TRUST_WORKSPACE=true"
else
    YOLO_ENV="-e OPENCODE_YOLO=1"
fi

# Append $RANDOM to guarantee a unique container name for every instance
CONTAINER_NAME="${AGENT}-yolo-$(basename "$WORKSPACE")-$RANDOM"

# 5. Execute the Sandbox
# - --workdir: Drops the agent exactly where you are
# - :rw gives write access ONLY to the current directory
docker run -it --rm \
  --name "$CONTAINER_NAME" \
  --workdir /workspace \
  -v "$WORKSPACE:/workspace:rw" \
  -v "$MEMORY_DIR:$TARGET_MOUNT" \
  $YOLO_ENV \
  "docker/sandbox-templates:$AGENT" $AGENT "$@"
