BUNDLE   = BookSaver.saver
BINARY   = $(BUNDLE)/Contents/MacOS/BookSaver
SOURCES  = BookSaverView.swift

ARCH    := $(shell uname -m | tr -d '[:space:]')
TARGET   = $(ARCH)-apple-macos12.0

# Popular Gutenberg book IDs to bundle as pre-loaded texts (first 80 KB each).
TEXTS_DIR   = Texts
PRELOAD_IDS = 1342 84 11 2701 76 345 174 1661 98 2554 5200 46 1184 768 1260 \
              74 161 219 514 730 36 43 120 205 600

.PHONY: all install uninstall clean texts

all: $(BUNDLE)

# ── Text pre-loading (parallel, skips files that already exist) ───────────────
texts:
	@mkdir -p $(TEXTS_DIR)
	@echo "Pre-loading book texts (parallel)..."
	@for id in $(PRELOAD_IDS); do \
		[ -f $(TEXTS_DIR)/pg$$id.txt ] || \
		curl -fsL -H "Range: bytes=0-81919" \
			-o $(TEXTS_DIR)/pg$$id.txt \
			"https://www.gutenberg.org/cache/epub/$$id/pg$$id.txt" & \
	done; wait
	@echo "Texts ready."

# ── Build ─────────────────────────────────────────────────────────────────────
$(BUNDLE): $(SOURCES) Info.plist
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	swiftc \
		-O \
		-target $(TARGET) \
		-framework ScreenSaver \
		-framework AppKit \
		-framework Foundation \
		-module-name BookSaver \
		-parse-as-library \
		-Xlinker -bundle \
		-o $(BINARY) \
		$(SOURCES)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	@echo "Built $(BUNDLE)"

# ── Install / uninstall ───────────────────────────────────────────────────────
# Texts are downloaded at install time only — not bundled in the build artifact.
INSTALL_DIR  = ~/Library/Screen\ Savers
INSTALL_DEST = $(INSTALL_DIR)/$(BUNDLE)

install: $(BUNDLE) texts
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DEST)
	cp -r $(BUNDLE) $(INSTALL_DEST)
	mkdir -p $(INSTALL_DEST)/Contents/Resources/Texts
	cp $(TEXTS_DIR)/pg*.txt $(INSTALL_DEST)/Contents/Resources/Texts/
	codesign --force --deep --sign - $(INSTALL_DEST)
	@echo "Installed — open System Settings › Screen Saver to activate"

uninstall:
	rm -rf ~/Library/Screen\ Savers/$(BUNDLE)
	@echo "Removed $(BUNDLE)"

clean:
	rm -rf $(BUNDLE)
