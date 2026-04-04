# BookSaver

A macOS screen saver that fetches a random book from [Project Gutenberg](https://www.gutenberg.org) and slowly scrolls through a section of it. Books are drawn from the top ~1000 most-read titles.

![BookSaver scrolling through a classic novel]

## Requirements

- macOS 12 (Monterey) or later
- Xcode Command Line Tools (`xcode-select --install`)
- An internet connection (fetches books at runtime)

## Install

```bash
make install
```

This will:
1. Download the Montserrat variable font from Google Fonts (first run only)
2. Compile the `.saver` bundle
3. Copy it to `~/Library/Screen Savers/`

Then open **System Settings → Screen Saver**, scroll down, and select **BookSaver**.

## Uninstall

```bash
make uninstall
```

## Build without installing

```bash
make          # produces BookSaver.saver in the current directory
make clean    # remove the built bundle
```

## How it works

- Picks a random page from the [Gutendex API](https://gutendex.com) (sorted by popularity, pages 1–32 ≈ top 1000 books) and selects a book with a plain-text format.
- Fetches the `.txt` file from Project Gutenberg, strips the standard header/footer, and picks a random ~40-paragraph window.
- Re-flows the text to fit the display width at the current font size.
- Scrolls via `CVDisplayLink` (vsync-aligned) for smooth animation.
- When a section finishes, a new book is fetched automatically.
