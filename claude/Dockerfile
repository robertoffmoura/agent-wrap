# Custom Claude Code sandbox — Docker has no official claude template.
# Base on the Gemini sandbox image for the same secure agent user + toolset
# pattern used by the antigravity/grok custom images in this repo.
FROM docker/sandbox-templates:gemini

USER root

# Install the official Claude Code CLI via its native installer, then copy
# the binary to /usr/local/bin so mounting state at /home/agent/.claude
# (and removing /root/.claude) cannot hide or break the executable.
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && cp /root/.local/bin/claude /usr/local/bin/claude \
    && chmod +x /usr/local/bin/claude \
    && rm -rf /root/.claude /root/.local

# xclip/wl-paste stand-ins that serve the host clipboard image saved by
# osc52pty, so Ctrl+V image paste works in the sandbox.
COPY clipboard-shim.sh /usr/local/bin/xclip
RUN chmod 755 /usr/local/bin/xclip \
    && ln -s xclip /usr/local/bin/wl-paste

USER agent

# Keep the base image ENTRYPOINT (tini --) so `docker run <image> claude ...` works.
CMD ["claude"]
