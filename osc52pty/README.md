# osc52pty

Host-side PTY wrapper that `aw` runs `docker run` inside, on macOS:

- Copy: catches OSC 52 clipboard escapes printed by the agent and pipes them
  to `pbcopy` (Terminal.app does not support OSC 52 natively).
- Image paste: when `OSC52PTY_CLIPBOARD_DIR` is set, each Ctrl+V first saves
  the clipboard image to `$OSC52PTY_CLIPBOARD_DIR/clip.png`, which the
  `xclip`/`wl-paste` shims in the sandbox image serve to the agent.

Install (Go required):

```bash
cd osc52pty && go install .   # -> ~/go/bin/osc52pty
```

Based on [roy2220/osc52pty](https://github.com/roy2220/osc52pty) v0.2.0 (MIT,
see `LICENSE`), with its dependencies updated to fix a crash with recent Go on
macOS (`x/crypto/ssh/terminal` -> `x/term`) and the image paste hook added in
`clipimage.go`.
