# Custom Grok Build sandbox — Docker has no official grok template.
# Base on the Gemini sandbox image for the same secure agent user + toolset
# pattern used by the antigravity custom image in this repo.
FROM docker/sandbox-templates:gemini

USER root

# Install the official Grok Build CLI, then replace the installer symlinks with
# a real binary under /usr/local/bin so mounting state at /home/agent/.grok
# (and removing /root/.grok) cannot hide or break the executable.
RUN curl -fsSL https://x.ai/cli/install.sh | bash \
    && GROK_BIN="$(ls /root/.grok/downloads/grok-linux-* 2>/dev/null | head -1)" \
    && test -n "$GROK_BIN" \
    && rm -f /usr/local/bin/grok /usr/local/bin/agent \
    && cp "$GROK_BIN" /usr/local/bin/grok \
    && chmod +x /usr/local/bin/grok \
    && ln -sf /usr/local/bin/grok /usr/local/bin/agent \
    && rm -rf /root/.grok

USER agent

# Keep the base image ENTRYPOINT (tini --) so `docker run <image> grok ...` works.
CMD ["grok"]
