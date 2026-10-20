package main

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// When OSC52PTY_CLIPBOARD_DIR is set, each Ctrl+V keystroke first saves the
// clipboard image (if any) to $OSC52PTY_CLIPBOARD_DIR/clip.png, then forwards
// the keystroke. A program that cannot reach the local clipboard (e.g. inside
// a container with the dir mounted) can then read the image when it handles
// the keystroke.
var clipboardDir = os.Getenv("OSC52PTY_CLIPBOARD_DIR")

var pasteKeys = [][]byte{
	[]byte("\x16"),        // Ctrl+V
	[]byte("\x1b[118;5u"), // Ctrl+V in the CSI u (kitty) keyboard protocol
}

// The output path is appended as the last argument.
var saveClipboardImageCmdLine = []string{
	"/usr/bin/osascript",
	"-e", "on run argv",
	"-e", "set png_data to (the clipboard as «class PNGf»)",
	"-e", "set fp to open for access POSIX file (item 1 of argv) with write permission",
	"-e", "set eof fp to 0",
	"-e", "write png_data to fp",
	"-e", "close access fp",
	"-e", "end run",
}

func containsPasteKey(data []byte) bool {
	for _, key := range pasteKeys {
		if bytes.Contains(data, key) {
			return true
		}
	}

	return false
}

func saveClipboardImage(saveClipboardImageCmdLine []string, dir string) error {
	path := filepath.Join(dir, "clip.png")
	tempPath := filepath.Join(dir, ".clip.png.tmp")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	args := append(append([]string(nil), saveClipboardImageCmdLine[1:]...), tempPath)
	command := exec.CommandContext(ctx, saveClipboardImageCmdLine[0], args...)

	if err := command.Run(); err != nil {
		// No image on the clipboard: drop the previous one so it isn't pasted again.
		os.Remove(tempPath)

		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			return err
		}

		return nil
	}

	// Rename so readers never see a partially written image.
	return os.Rename(tempPath, path)
}
