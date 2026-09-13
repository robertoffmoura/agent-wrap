# Custom OpenCode sandbox — installs the latest CLI at build time.
# The base docker/sandbox-templates:opencode bakes in an older opencode, and
# its built-in auto-updater re-installs the latest version on every boot (a
# pointless ~13s churn in an ephemeral --rm container that discards the result).
# OPENCODE_DISABLE_AUTOUPDATE=1 disables that; rebuild the image to pick up a
# newer version.
FROM docker/sandbox-templates:opencode

USER root

RUN npm install -g opencode-ai --prefix /usr/local/share/npm-global

ENV OPENCODE_DISABLE_AUTOUPDATE=1

USER agent

# Keep the base image ENTRYPOINT (tini --) so `docker run <image> opencode ...` works.
CMD ["opencode"]
