BUNDLE   = BookSaver.saver
BINARY   = $(BUNDLE)/Contents/MacOS/BookSaver
SOURCES  = BookSaverView.swift

ARCH    := $(shell uname -m | tr -d '[:space:]')
TARGET   = $(ARCH)-apple-macos12.0

FONTS_DIR      = Fonts
# Variable font covers all weights; URL-encode the brackets.
FONT_VARIABLE  = $(FONTS_DIR)/Montserrat-Variable.ttf
FONT_URL       = https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf

.PHONY: all install uninstall clean fonts

all: $(BUNDLE)

# ── Font download ─────────────────────────────────────────────────────────────
fonts: $(FONT_VARIABLE)

$(FONT_VARIABLE):
	mkdir -p $(FONTS_DIR)
	curl -fL -o $@ "$(FONT_URL)"

# ── Build ─────────────────────────────────────────────────────────────────────
$(BUNDLE): $(SOURCES) Info.plist fonts
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	swiftc \
		-target $(TARGET) \
		-framework ScreenSaver \
		-framework AppKit \
		-framework Foundation \
		-framework CoreVideo \
		-framework CoreText \
		-module-name BookSaver \
		-parse-as-library \
		-Xlinker -bundle \
		-o $(BINARY) \
		$(SOURCES)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	cp $(FONT_VARIABLE) $(BUNDLE)/Contents/Resources/
	@echo "Built $(BUNDLE)"

# ── Install / uninstall ───────────────────────────────────────────────────────
install: $(BUNDLE)
	mkdir -p ~/Library/Screen\ Savers
	cp -r $(BUNDLE) ~/Library/Screen\ Savers/
	@echo "Installed — open System Settings › Screen Saver to activate"

uninstall:
	rm -rf ~/Library/Screen\ Savers/$(BUNDLE)
	@echo "Removed $(BUNDLE)"

clean:
	rm -rf $(BUNDLE)
