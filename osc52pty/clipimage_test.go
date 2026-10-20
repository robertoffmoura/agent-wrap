package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSaveClipboardImage(t *testing.T) {
	dir, err := ioutil.TempDir("", "osc52pty")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	defer os.RemoveAll(dir)
	path := filepath.Join(dir, "clip.png")

	err = saveClipboardImage([]string{"sh", "-c", `printf PNGDATA > "$1"`, "sh"}, dir)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	data, err := ioutil.ReadFile(path)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.Equal(t, "PNGDATA", string(data))

	// No image on the clipboard: the previous one is removed.
	err = saveClipboardImage([]string{"false"}, dir)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	_, err = os.Stat(path)
	assert.True(t, os.IsNotExist(err))
	_, err = os.Stat(filepath.Join(dir, ".clip.png.tmp"))
	assert.True(t, os.IsNotExist(err))
}

func TestContainsPasteKey(t *testing.T) {
	assert.True(t, containsPasteKey([]byte("\x16")))
	assert.True(t, containsPasteKey([]byte("a\x1b[118;5u")))
	assert.False(t, containsPasteKey([]byte("v")))
}
