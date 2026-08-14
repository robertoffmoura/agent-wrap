# Start from the secure Docker sandbox template
FROM docker/sandbox-templates:gemini

# Switch to root to run the installer
USER root

# Run the installer, find the binary it downloaded, and move it to a global path
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash \
    && find / -name "agy" -type f -exec mv {} /usr/local/bin/agy \; \
    && chmod +x /usr/local/bin/agy

# Drop privileges back down to the isolated agent user
USER agent

# Keep the base image ENTRYPOINT (tini --) so `docker run <image> agy ...` works.
CMD ["agy"]
