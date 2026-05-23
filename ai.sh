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

echo "Starting $AGENT in YOLO mode..."
echo "✅ Workspace (Read/Write): $WORKSPACE"
echo "⚠️ Network: Full Egress (Proxy filtering not yet applied)"

# 3. Set Agent-Specific YOLO Environment Variables
if [ "$AGENT" = "gemini" ]; then
    # Ensure API Key is present for Gemini
    if [ -z "$GEMINI_API_KEY" ]; then
        echo "❌ Error: GEMINI_API_KEY environment variable is missing!"
        echo "Please set it in your ~/.zprofile"
        exit 1
    fi
    YOLO_ENV="-e GEMINI_YOLO_MODE=true -e GEMINI_API_KEY=$GEMINI_API_KEY"
else
    YOLO_ENV="-e OPENCODE_YOLO=1"
fi

# Append $RANDOM to guarantee a unique container name for every instance
CONTAINER_NAME="${AGENT}-yolo-$(basename "$WORKSPACE")-$RANDOM"

# 4. Execute the Sandbox
# - --workdir: Drops the agent exactly where you are
# - :rw gives write access ONLY to the current directory
docker run -it --rm \
  --name "$CONTAINER_NAME" \
  --workdir /workspace \
  -v "$WORKSPACE:/workspace:rw" \
  $YOLO_ENV \
  "docker/sandbox-templates:$AGENT" "$@"
