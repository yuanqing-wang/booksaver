import ScreenSaver
import AppKit
import CoreText

@objc(BookSaverView)
class BookSaverView: ScreenSaverView {

    // MARK: - Models

    struct Book {
        let title: String
        let author: String
        let lines: [String]
        let totalHeight: CGFloat
    }

    // Hardcoded catalog of popular Gutenberg books.
    // Eliminates the Gutendex API call entirely — every load is one ~80 KB request.
    private static let catalog: [(id: Int, title: String, author: String)] = [
        (11,    "Alice's Adventures in Wonderland",         "Lewis Carroll"),
        (12,    "Through the Looking-Glass",                "Lewis Carroll"),
        (16,    "Peter Pan",                                "J. M. Barrie"),
        (35,    "The Time Machine",                         "H. G. Wells"),
        (36,    "The War of the Worlds",                    "H. G. Wells"),
        (43,    "Dr Jekyll and Mr Hyde",                    "Robert Louis Stevenson"),
        (46,    "A Christmas Carol",                        "Charles Dickens"),
        (55,    "The Wonderful Wizard of Oz",               "L. Frank Baum"),
        (74,    "The Adventures of Tom Sawyer",             "Mark Twain"),
        (76,    "Adventures of Huckleberry Finn",           "Mark Twain"),
        (84,    "Frankenstein",                             "Mary Shelley"),
        (98,    "A Tale of Two Cities",                     "Charles Dickens"),
        (105,   "Persuasion",                               "Jane Austen"),
        (120,   "Treasure Island",                          "Robert Louis Stevenson"),
        (135,   "Les Misérables",                           "Victor Hugo"),
        (161,   "Sense and Sensibility",                    "Jane Austen"),
        (174,   "The Picture of Dorian Gray",               "Oscar Wilde"),
        (205,   "Walden",                                   "Henry David Thoreau"),
        (219,   "Heart of Darkness",                        "Joseph Conrad"),
        (244,   "A Study in Scarlet",                       "Arthur Conan Doyle"),
        (345,   "Dracula",                                  "Bram Stoker"),
        (514,   "Little Women",                             "Louisa May Alcott"),
        (600,   "Notes from the Underground",               "Fyodor Dostoevsky"),
        (730,   "Oliver Twist",                             "Charles Dickens"),
        (768,   "Emma",                                     "Jane Austen"),
        (844,   "The Importance of Being Earnest",          "Oscar Wilde"),
        (910,   "Bartleby, the Scrivener",                  "Herman Melville"),
        (996,   "Don Quixote",                              "Miguel de Cervantes"),
        (1080,  "A Modest Proposal",                        "Jonathan Swift"),
        (1184,  "The Count of Monte Cristo",                "Alexandre Dumas"),
        (1232,  "The Prince",                               "Niccolò Machiavelli"),
        (1260,  "Jane Eyre",                                "Charlotte Brontë"),
        (1342,  "Pride and Prejudice",                      "Jane Austen"),
        (1400,  "Great Expectations",                       "Charles Dickens"),
        (1661,  "The Adventures of Sherlock Holmes",        "Arthur Conan Doyle"),
        (1727,  "The Odyssey",                              "Homer"),
        (1952,  "The Yellow Wallpaper",                     "Charlotte Perkins Gilman"),
        (1998,  "Thus Spoke Zarathustra",                   "Friedrich Nietzsche"),
        (2097,  "The Jungle",                               "Upton Sinclair"),
        (2148,  "Twenty Thousand Leagues under the Sea",    "Jules Verne"),
        (2542,  "A Doll's House",                           "Henrik Ibsen"),
        (2554,  "Crime and Punishment",                     "Fyodor Dostoevsky"),
        (2591,  "Grimms' Fairy Tales",                      "Brothers Grimm"),
        (2600,  "War and Peace",                            "Leo Tolstoy"),
        (2701,  "Moby-Dick",                                "Herman Melville"),
        (2814,  "Dubliners",                                "James Joyce"),
        (3207,  "The Republic",                             "Plato"),
        (3296,  "Pygmalion",                                "George Bernard Shaw"),
        (4300,  "Ulysses",                                  "James Joyce"),
        (4363,  "The Brothers Karamazov",                   "Fyodor Dostoevsky"),
        (5200,  "The Metamorphosis",                        "Franz Kafka"),
        (5827,  "The Scarlet Letter",                       "Nathaniel Hawthorne"),
        (8800,  "Candide",                                  "Voltaire"),
        (25344, "The Scarlet Pimpernel",                    "Baroness Orczy"),
        (23,    "Narrative of the Life of Frederick Douglass", "Frederick Douglass"),
        (45,    "Anne of Green Gables",                     "L. M. Montgomery"),
        (158,   "Sense and Sensibility",                    "Jane Austen"),
        (766,   "David Copperfield",                        "Charles Dickens"),
        (863,   "Lady Windermere's Fan",                    "Oscar Wilde"),
        (1322,  "The Iliad",                                "Homer"),
        (1497,  "The Republic",                             "Plato"),
        (2003,  "Around the World in Eighty Days",          "Jules Verne"),
        (2761,  "The Brothers Karamazov",                   "Fyodor Dostoevsky"),
        (5740,  "The Island of Dr. Moreau",                 "H. G. Wells"),
        (7370,  "Beyond Good and Evil",                     "Friedrich Nietzsche"),
        (16,    "Peter Pan in Kensington Gardens",          "J. M. Barrie"),
        (209,   "The Turn of the Screw",                    "Henry James"),
        (2244,  "A Room with a View",                       "E. M. Forster"),
        (2245,  "Howards End",                              "E. M. Forster"),
        (2500,  "Siddhartha",                               "Hermann Hesse"),
        (3600,  "The Metamorphoses",                        "Ovid"),
        (4517,  "The Awakening",                            "Kate Chopin"),
        (6130,  "The Iliad",                                "Homer"),
        (14,    "The Tragedy of Romeo and Juliet",          "William Shakespeare"),
        (1041,  "The Merry Adventures of Robin Hood",       "Howard Pyle"),
        (2500,  "Siddhartha",                               "Hermann Hesse"),
        (30254, "Mansfield Park",                           "Jane Austen"),
        (141,   "Northanger Abbey",                         "Jane Austen"),
        (1342,  "Pride and Prejudice",                      "Jane Austen"),
        (2148,  "Twenty Thousand Leagues under the Sea",    "Jules Verne"),
    ]

    // MARK: - Display state

    private var book: Book?
    private var scrollOffset: CGFloat = 0
    private var isLoading = true
    private var loadingFrame = 0

    // MARK: - Pipeline state
    //
    // nextBook is pre-fetched while the current book is scrolling.
    // After the first load, every transition is instant.

    private var nextBook: Book?
    private var isFetchingNext = false
    private var usedIDs: Set<Int> = []   // avoid repeating books in a session

    // MARK: - Networking

    private static let session: URLSession = {
        // .ephemeral avoids disk-cache init delays in the screen saver process.
        // isDiscretionary=false / allowsExpensive=true prevent the OS from
        // deferring requests for energy savings when the screensaver is active.
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest        = 30
        cfg.timeoutIntervalForResource       = 60
        cfg.isDiscretionary                  = false
        cfg.allowsExpensiveNetworkAccess     = true
        cfg.allowsConstrainedNetworkAccess   = true
        return URLSession(configuration: cfg)
    }()

    // MARK: - Animation

    override func startAnimation() {
        animationTimeInterval = 1.0 / 60.0
        super.startAnimation()
    }

    override func animateOneFrame() {
        if isLoading {
            loadingFrame += 1
        } else if let current = book {
            scrollOffset += scrollSpeed
            if scrollOffset > current.totalHeight + bounds.height * 0.25 {
                advanceBook()
            }
        }
        setNeedsDisplay(bounds)
    }

    // MARK: - Appearance

    private let bgColor   = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
    private let textColor = NSColor(white: 0.88, alpha: 1)
    private let dimColor  = NSColor(white: 0.36, alpha: 1)

    private var fontSize: CGFloat { isPreview ? 9 : max(26, bounds.width / 40) }

    private var textFont: NSFont {
        let sz = fontSize
        return NSFont(name: "Montserrat-Regular", size: sz)
            ?? NSFont(name: "Montserrat", size: sz)
            ?? NSFont.systemFont(ofSize: sz, weight: .regular)
    }
    private var metaFontSize: CGFloat { isPreview ? 7 : fontSize * 0.62 }
    private var metaFont: NSFont {
        let sz = metaFontSize
        return NSFont(name: "Montserrat-Italic", size: sz)
            ?? NSFont(name: "Montserrat", size: sz)
            ?? NSFont.systemFont(ofSize: sz, weight: .regular)
    }
    private var metaAreaHeight: CGFloat { metaFontSize * 3.2 }
    private var lineHeight: CGFloat     { fontSize * 1.45 }
    private var sideMargin: CGFloat     { bounds.width * 0.04 }
    private var textWidth:  CGFloat     { bounds.width - sideMargin * 2 }
    private var scrollSpeed: CGFloat    { isPreview ? 0.35 : 0.9 }

    // MARK: - Init

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        registerMontserrat()
        // Defer one run-loop tick so bounds are finalised before we read them.
        DispatchQueue.main.async { [weak self] in self?.loadInitialBook() }
    }

    private func loadInitialBook() {
        if let b = loadBundledBook() {
            book = b
            isLoading = false
        }
        fetchNextBook()   // pre-fetch next (network) while first book is showing
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Font registration

    private static var fontsRegistered = false

    private func registerMontserrat() {
        guard !Self.fontsRegistered else { return }
        Self.fontsRegistered = true
        let bundle = Bundle(for: BookSaverView.self)
        for resource in ["Montserrat-Variable", "Montserrat-Italic-Variable"] {
            if let url = bundle.url(forResource: resource, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    // MARK: - Pipeline

    private func pickEntry() -> (id: Int, title: String, author: String)? {
        let unused = Self.catalog.filter { !usedIDs.contains($0.id) }
        if let entry = (unused.isEmpty ? Self.catalog : unused).randomElement() {
            usedIDs.insert(entry.id)
            if usedIDs.count >= Self.catalog.count { usedIDs.removeAll() }
            return entry
        }
        return nil
    }

    private func fetchNextBook() {
        guard !isFetchingNext, let entry = pickEntry() else { return }
        isFetchingNext = true

        let url = URL(string: "https://www.gutenberg.org/cache/epub/\(entry.id)/pg\(entry.id).txt")!
        var req = URLRequest(url: url)
        req.setValue("bytes=0-81919", forHTTPHeaderField: "Range")

        Self.session.dataTask(with: req) { [weak self] data, response, _ in
            guard let self else { return }

            // Reject non-text responses (HTML error pages, redirects, etc.)
            if let http = response as? HTTPURLResponse,
               http.statusCode != 200 && http.statusCode != 206 {
                DispatchQueue.main.async { [weak self] in
                    self?.isFetchingNext = false; self?.fetchNextBook()
                }
                return
            }

            guard
                let data,
                let raw = String(data: data, encoding: .utf8)
                       ?? String(data: data, encoding: .isoLatin1)
                       ?? String(data: data, encoding: .windowsCP1252)
            else {
                DispatchQueue.main.async { [weak self] in
                    self?.isFetchingNext = false
                    self?.fetchNextBook()
                }
                return
            }

            // Skip HTML error pages that slipped through (Gutenberg returns HTML for missing IDs)
            let prefix = raw.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !prefix.hasPrefix("<") else {
                DispatchQueue.main.async { [weak self] in
                    self?.isFetchingNext = false; self?.fetchNextBook()
                }
                return
            }

            let paragraphs = self.extractParagraphs(from: raw)
            guard !paragraphs.isEmpty else {
                DispatchQueue.main.async { [weak self] in
                    self?.isFetchingNext = false; self?.fetchNextBook()
                }
                return
            }

            // Read layout values and do reflow on main thread (bounds is main-thread-only).
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFetchingNext = false

                let lines = Self.reflow(paragraphs, font: self.textFont, maxWidth: self.textWidth)
                guard !lines.isEmpty else { self.fetchNextBook(); return }

                self.nextBook = Book(
                    title:       entry.title,
                    author:      entry.author,
                    lines:       lines,
                    totalHeight: CGFloat(lines.count) * self.lineHeight
                )
                if self.isLoading { self.advanceBook() }
            }
        }.resume()
    }

    private func advanceBook() {
        if let ready = nextBook {
            // Network-fetched book is ready — use it.
            book         = ready
            nextBook     = nil
            isLoading    = false
            scrollOffset = 0
            fetchNextBook()
        } else if let bundled = loadBundledBook() {
            // Network wasn't ready — fall back to a bundled text instantly.
            book         = bundled
            isLoading    = false
            scrollOffset = 0
            if !isFetchingNext { fetchNextBook() }
        } else {
            isLoading = true
            book      = nil
        }
    }

    /// Load a random unused pre-bundled text from Resources/Texts/.
    /// Returns nil only if no bundled texts exist at all.
    private func loadBundledBook() -> Book? {
        let bundle = Bundle(for: BookSaverView.self)
        guard let urls = bundle.urls(forResourcesWithExtension: "txt", subdirectory: "Texts"),
              !urls.isEmpty else { return nil }

        // Pick an unused bundled file, cycling when all have been shown.
        let unused = urls.filter { !usedIDs.contains(idFrom(url: $0)) }
        guard let url = (unused.isEmpty ? urls : unused).randomElement() else { return nil }

        let id = idFrom(url: url)
        usedIDs.insert(id)
        if usedIDs.count >= Self.catalog.count + urls.count { usedIDs.removeAll() }

        guard let raw = (try? String(contentsOf: url, encoding: .utf8))
                       ?? (try? String(contentsOf: url, encoding: .isoLatin1)) else { return nil }

        let prefix = raw.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !prefix.hasPrefix("<") else { return nil }

        let entry  = Self.catalog.first { $0.id == id }
        let title  = entry?.title  ?? "Classic Literature"
        let author = entry?.author ?? "Project Gutenberg"

        let paragraphs = extractParagraphs(from: raw)
        guard !paragraphs.isEmpty else { return nil }
        let lines = Self.reflow(paragraphs, font: textFont, maxWidth: textWidth)
        guard !lines.isEmpty else { return nil }
        return Book(title: title, author: author, lines: lines,
                    totalHeight: CGFloat(lines.count) * lineHeight)
    }

    /// Extract the Gutenberg ID from a filename like "pg1342.txt".
    private func idFrom(url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent.dropFirst(2)) ?? 0
    }

    // MARK: - Text processing

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

        let window   = min(120, paras.count)
        let maxBegin = max(0, paras.count - window)
        let begin    = Int.random(in: 0..<max(1, maxBegin))
        return Array(paras[begin..<(begin + window)])
    }

    private static func reflow(_ paragraphs: [String], font: NSFont, maxWidth: CGFloat) -> [String] {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var result: [String] = []

        for (pi, para) in paragraphs.enumerated() {
            if pi > 0 { result.append("") }
            let words = para.components(separatedBy: " ").filter { !$0.isEmpty }
            var current = ""
            for word in words {
                let candidate = current.isEmpty ? word : current + " " + word
                if (candidate as NSString).size(withAttributes: attrs).width > maxWidth, !current.isEmpty {
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
        let lh      = lineHeight
        let metaTop = metaAreaHeight

        for (i, line) in book.lines.enumerated() {
            let y = bounds.height - CGFloat(i + 1) * lh - scrollOffset
            guard y > metaTop - lh * 0.1, y < bounds.height + lh else { continue }
            let r = NSRect(x: sideMargin, y: y, width: textWidth, height: lh * 2)
            (line as NSString).draw(in: r, withAttributes: tAttrs)
        }

        let fadeH = metaAreaHeight * 1.5
        NSGradient(colors: [bgColor.withAlphaComponent(0), bgColor],
                   atLocations: [0, 1],
                   colorSpace: .genericRGB)?
            .draw(in: NSRect(x: 0, y: metaAreaHeight, width: bounds.width, height: fadeH),
                  angle: 270)

        bgColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: metaAreaHeight).fill()

        drawMeta(title: book.title, author: book.author)
    }

    private func drawMeta(title: String, author: String) {
        let mAttrs: [NSAttributedString.Key: Any] = [
            .font:            metaFont,
            .foregroundColor: dimColor
        ]
        let label = "\(title)  ·  \(author)"
        let sz    = (label as NSString).size(withAttributes: mAttrs)
        let y     = (metaAreaHeight - sz.height) / 2
        (label as NSString).draw(
            in: NSRect(x: sideMargin, y: y, width: textWidth, height: sz.height + 2),
            withAttributes: mAttrs)
    }

    // MARK: - Misc

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
