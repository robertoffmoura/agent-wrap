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

# 3. Locate and Verify the Conda Environment
if command -v conda &> /dev/null; then
    CONDA_BASE=$(conda info --base)
else
    # Fallback if conda isn't in your immediate PATH
    CONDA_BASE="$HOME/miniconda3"
fi

if [[ ! -d "$CONDA_BASE" ]]; then
    echo "❌ Error: Conda base directory not found at $CONDA_BASE."
    echo "Please ensure Conda is installed or update the fallback path in this script."
    exit 1
fi

echo "Starting $AGENT in YOLO mode..."
echo "✅ Workspace (Read/Write): $WORKSPACE"
echo "✅ Conda Environment (Read-Only): $CONDA_BASE"
echo "⚠️ Network: Full Egress (Proxy filtering not yet applied)"

# 4. Set Agent-Specific YOLO Environment Variables
if [ "$AGENT" = "gemini" ]; then
    YOLO_ENV="-e GEMINI_YOLO_MODE=true"
else
    YOLO_ENV="-e OPENCODE_YOLO=1"
fi

# 4. Execute the Sandbox
# - --workdir: Drops the agent exactly where you are
# - :rw gives write access ONLY to the current directory
# - :ro ensures the agent can run python/bash but cannot corrupt your host Conda env
docker run -it --rm \
  --name "${AGENT}-yolo-$(basename "$WORKSPACE")" \
  --workdir /workspace \
  -v "$WORKSPACE:/workspace:rw" \
  -v "$CONDA_BASE:$CONDA_BASE:ro" \
  -e PATH="$CONDA_BASE/bin:$PATH" \
  $YOLO_ENV \
  "docker/sandbox-templates:$AGENT" "$@"
