import ScreenSaver
import AppKit
import CoreVideo
import CoreText

@objc(BookSaverView)
class BookSaverView: ScreenSaverView {

    // MARK: - Model

    struct Book {
        let title: String
        let author: String
        let lines: [String]      // pre-wrapped display lines
        let totalHeight: CGFloat  // sum of all line slots
    }

    // MARK: - State

    private var book: Book?
    private var scrollOffset: CGFloat = 0
    private var isLoading = true
    private var loadingFrame = 0
    private var isFetching = false

    // CVDisplayLink drives animation at the display's native refresh rate
    private var displayLink: CVDisplayLink?

    // MARK: - Appearance

    private let bgColor   = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
    private let textColor = NSColor(white: 0.88, alpha: 1)
    private let dimColor  = NSColor(white: 0.36, alpha: 1)

    /// Adaptive font size: scales with screen width so text fills the display.
    private var fontSize: CGFloat {
        isPreview ? 9 : max(26, bounds.width / 40)
    }
    private var textFont: NSFont {
        let sz = fontSize
        let name = Self.montserratPostScriptName
        return NSFont(name: name, size: sz)
            ?? NSFont(name: "Montserrat-Regular", size: sz)
            ?? NSFont(name: "Montserrat", size: sz)
            ?? NSFont.systemFont(ofSize: sz, weight: .regular)
    }
    private var metaFont: NSFont {
        let sz = isPreview ? 6.5 : 12.0 as CGFloat
        let name = Self.montserratPostScriptName
        return NSFont(name: name, size: sz)
            ?? NSFont(name: "Montserrat-Regular", size: sz)
            ?? NSFont.systemFont(ofSize: sz, weight: .regular)
    }
    /// Tight line height (1.45×) so text truly fills vertical space.
    private var lineHeight: CGFloat { fontSize * 1.45 }
    /// Narrow margins so text occupies most of the width.
    private var sideMargin: CGFloat { bounds.width * 0.04 }
    private var textWidth:  CGFloat { bounds.width - sideMargin * 2 }

    // Pixels scrolled per display-link tick (~60 fps → ~54 px/s at 0.9 px/tick)
    private var scrollSpeed: CGFloat { isPreview ? 0.35 : 0.9 }

    // MARK: - Init

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        registerMontserrat()
        fetchBook()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Font registration

    private static var fontsRegistered = false
    private static var montserratPostScriptName: String = "Montserrat"

    private func registerMontserrat() {
        guard !Self.fontsRegistered else { return }
        Self.fontsRegistered = true
        let bundle = Bundle(for: BookSaverView.self)
        guard let url = bundle.url(forResource: "Montserrat-Variable", withExtension: "ttf") else { return }

        var errors: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errors)

        // Discover the actual PostScript name the font registered under.
        if let provider = CGDataProvider(url: url as CFURL),
           let cgFont   = CGFont(provider) {
            let name = cgFont.postScriptName as String? ?? "Montserrat"
            Self.montserratPostScriptName = name
        }
    }

    // MARK: - CVDisplayLink (vsync-aligned animation)

    override func startAnimation() {
        animationTimeInterval = 1_000  // disable the built-in timer
        super.startAnimation()
        guard displayLink == nil else { return }

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }

        let ctx = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, ctx) -> CVReturn in
            guard let ctx else { return kCVReturnError }
            let me = Unmanaged<BookSaverView>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { me.tick() }
            return kCVReturnSuccess
        }, ctx)

        CVDisplayLinkStart(link)
        displayLink = link
    }

    override func stopAnimation() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
        super.stopAnimation()
    }

    // Called once per display refresh (≈60 fps).
    private func tick() {
        if isLoading {
            loadingFrame += 1
        } else if let book {
            scrollOffset += scrollSpeed
            if scrollOffset > book.totalHeight + bounds.height * 0.25 {
                fetchBook()
            }
        }
        setNeedsDisplay(bounds)
    }

    // No-op — CVDisplayLink owns the animation loop.
    override func animateOneFrame() {}

    // MARK: - Fetch (top ~1000 most popular books)

    private func fetchBook() {
        guard !isFetching else { return }
        isFetching   = true
        isLoading    = true
        book         = nil
        scrollOffset = 0

        // Gutendex sorts by popularity descending by default.
        // Pages 1–32 × 32 results = ~1024 books ≈ top 1000.
        let page   = Int.random(in: 1...32)
        let urlStr = "https://gutendex.com/books/?page=\(page)&mime_type=text%2Fplain"
        guard let url = URL(string: urlStr) else { isFetching = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            guard
                let data,
                let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                !results.isEmpty
            else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.isFetching = false; self?.fetchBook()
                }
                return
            }

            let meta   = results[Int.random(in: 0..<results.count)]
            let id     = meta["id"] as? Int ?? 0
            let title  = (meta["title"] as? String ?? "Unknown").trimmingCharacters(in: .whitespaces)
            var author = "Unknown Author"
            if let authors = meta["authors"] as? [[String: Any]], let first = authors.first {
                author = (first["name"] as? String ?? author).trimmingCharacters(in: .whitespaces)
            }

            var textURL: URL?
            if let formats = meta["formats"] as? [String: String] {
                for key in ["text/plain; charset=utf-8",
                            "text/plain; charset=us-ascii",
                            "text/plain"] {
                    if let s = formats[key], let u = URL(string: s) { textURL = u; break }
                }
            }
            textURL = textURL ?? URL(string: "https://www.gutenberg.org/cache/epub/\(id)/pg\(id).txt")

            guard let fetchURL = textURL else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.isFetching = false; self?.fetchBook()
                }
                return
            }
            self.fetchText(from: fetchURL, title: title, author: author)
        }.resume()
    }

    private func fetchText(from url: URL, title: String, author: String) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            guard
                let data,
                let raw = String(data: data, encoding: .utf8)
                       ?? String(data: data, encoding: .isoLatin1)
                       ?? String(data: data, encoding: .windowsCP1252)
            else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.isFetching = false; self?.fetchBook()
                }
                return
            }

            // Extract + reflow on a background queue; results dispatched to main.
            let paragraphs = self.extractParagraphs(from: raw)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFetching = false
                guard !paragraphs.isEmpty else { self.fetchBook(); return }

                let lines = self.reflow(paragraphs)
                guard !lines.isEmpty else { self.fetchBook(); return }

                let totalH = CGFloat(lines.count) * self.lineHeight
                self.book      = Book(title: title, author: author,
                                      lines: lines, totalHeight: totalH)
                self.isLoading = false
                self.scrollOffset = 0
            }
        }.resume()
    }

    // MARK: - Text processing

    /// Strip Gutenberg header/footer, collapse lines into paragraphs,
    /// then return a random window of ~40 paragraphs.
    private func extractParagraphs(from raw: String) -> [String] {
        var all = raw.components(separatedBy: "\n")

        var start = 0, end = all.count
        for (i, line) in all.enumerated() {
            if line.contains("*** START OF") || line.contains("***START OF") { start = i + 1 }
            if line.contains("*** END OF")   || line.contains("***END OF")   { end   = i; break }
        }
        if start == 0 { start = min(60, all.count / 8) }
        all = Array(all[start..<end])
        guard all.count > 80 else { return [] }

        // Collect non-empty runs as paragraphs (join Gutenberg hard-wraps).
        var paras: [String] = []
        var current: [String] = []
        for line in all {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty {
                if !current.isEmpty { paras.append(current.joined(separator: " ")); current = [] }
            } else {
                current.append(t)
            }
        }
        if !current.isEmpty { paras.append(current.joined(separator: " ")) }

        guard paras.count > 4 else { return [] }

        let window   = min(45, paras.count)
        let maxBegin = max(0, paras.count - window)
        let begin    = Int.random(in: 0..<max(1, maxBegin))
        return Array(paras[begin..<(begin + window)])
    }

    /// Word-wrap each paragraph into display-width lines; blank lines separate paragraphs.
    private func reflow(_ paragraphs: [String]) -> [String] {
        let attrs: [NSAttributedString.Key: Any] = [.font: textFont]
        let maxW = textWidth
        var result: [String] = []

        for (pi, para) in paragraphs.enumerated() {
            if pi > 0 { result.append("") }          // blank line between paragraphs

            let words = para.components(separatedBy: " ").filter { !$0.isEmpty }
            var current = ""
            for word in words {
                let candidate = current.isEmpty ? word : current + " " + word
                if (candidate as NSString).size(withAttributes: attrs).width > maxW, !current.isEmpty {
                    result.append(current)
                    current = word
                } else {
                    current = candidate
                }
            }
            if !current.isEmpty { result.append(current) }
        }
        return result
    }

    // MARK: - Drawing

    override func draw(_ rect: NSRect) {
        bgColor.setFill()
        bounds.fill()
        isLoading ? drawSpinner() : drawBook()
    }

    private func drawSpinner() {
        let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
        let label  = "\(frames[loadingFrame % frames.count])  Fetching from Project Gutenberg…"
        let sz     = isPreview ? 8.0 : 14.0 as CGFloat
        let attrs: [NSAttributedString.Key: Any] = [
            .font:            NSFont.monospacedSystemFont(ofSize: sz, weight: .regular),
            .foregroundColor: dimColor
        ]
        let s = (label as NSString).size(withAttributes: attrs)
        (label as NSString).draw(
            at: NSPoint(x: (bounds.width - s.width) / 2,
                        y: (bounds.height - s.height) / 2),
            withAttributes: attrs)
    }

    private func drawBook() {
        guard let book else { return }

        let tAttrs: [NSAttributedString.Key: Any] = [
            .font:            textFont,
            .foregroundColor: textColor
        ]

        let lh = lineHeight
        // y origin is bottom-left in AppKit (non-flipped).
        // Line i appears at: bounds.height - (i+1)*lh - scrollOffset
        for (i, line) in book.lines.enumerated() {
            let y = bounds.height - CGFloat(i + 1) * lh - scrollOffset
            guard y > -lh * 2, y < bounds.height + lh else { continue }
            let r = NSRect(x: sideMargin, y: y, width: textWidth, height: lh * 2)
            (line as NSString).draw(in: r, withAttributes: tAttrs)
        }

        drawMeta(title: book.title, author: book.author)
    }

    private func drawMeta(title: String, author: String) {
        let mAttrs: [NSAttributedString.Key: Any] = [
            .font:            metaFont,
            .foregroundColor: dimColor
        ]
        let label  = "\(title)  ·  \(author)  ·  Project Gutenberg"
        let pad    = isPreview ? 3.0 : 13.0 as CGFloat
        let stripH = isPreview ? 20.0 : 46.0 as CGFloat

        // Soft fade-to-background strip so the label is always legible.
        NSGradient(colors: [bgColor, bgColor.withAlphaComponent(0)],
                   atLocations: [0, 1],
                   colorSpace: .genericRGB)?
            .draw(in: NSRect(x: 0, y: 0, width: bounds.width, height: stripH), angle: 90)

        (label as NSString).draw(
            in: NSRect(x: sideMargin, y: pad, width: textWidth, height: stripH),
            withAttributes: mAttrs)
    }

    // MARK: - Misc

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
