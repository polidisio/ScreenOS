import AppKit

/// The overlay panel shown when the window switcher is active.
/// Displays a horizontal strip of window thumbnails with app icons and titles.
public final class SwitcherPanel: NSWindow {

    // MARK: - Layout constants

    private enum Layout {
        static let panelWidth: CGFloat = 720
        static let panelHeight: CGFloat = 340
        static let cornerRadius: CGFloat = 12
        static let itemSize = NSSize(width: 180, height: 260)
        static let itemSpacing: CGFloat = 12
        static let padding: CGFloat = 20
    }

    // MARK: - Properties

    private let scrollView = NSScrollView()
    private let collectionView: NSCollectionView
    private var windows: [ScreenWindow] = []
    private var filteredWindows: [ScreenWindow] = []
    private var selectedIndex: Int = 0
    private let searchField = NSSearchField()

    public var onWindowSelected: ((ScreenWindow) -> Void)?

    // MARK: - Init

    public init() {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = Layout.itemSize
        layout.minimumInteritemSpacing = Layout.itemSpacing
        layout.minimumLineSpacing = Layout.itemSpacing
        layout.scrollDirection = .horizontal
        layout.sectionInset = NSEdgeInsets(
            top: Layout.padding,
            left: Layout.padding,
            bottom: Layout.padding,
            right: Layout.padding
        )

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.wantsLayer = true

        let screenRect = NSScreen.main?.frame ?? .zero
        let panelRect = CGRect(
            x: (screenRect.width - Layout.panelWidth) / 2,
            y: (screenRect.height - Layout.panelHeight) / 2 + 60,
            width: Layout.panelWidth,
            height: Layout.panelHeight
        )

        super.init(
            contentRect: panelRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false

        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        let containerFrame = self.contentRect(forFrameRect: self.frame)
        let containerView = NSView(frame: containerFrame)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Layout.cornerRadius
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView = containerView

        // Visual blur effect behind the panel
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = Layout.cornerRadius
        containerView.addSubview(visualEffect, positioned: .below, relativeTo: nil)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filter windows..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.bezelStyle = .roundedBezel
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        containerView.addSubview(searchField)

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SwitcherCell.self, forItemWithIdentifier: SwitcherCell.identifier)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        containerView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    // MARK: - Public API

    public func show(with windows: [ScreenWindow]) {
        self.windows = windows
        filteredWindows = windows
        selectedIndex = 0
        searchField.stringValue = ""

        collectionView.reloadData()
        updateSelection()
        makeKeyAndOrderFront(nil)
    }

    public func closePanel() {
        orderOut(nil)
    }

    public func navigateNext() {
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % filteredWindows.count
        updateSelection()
        scrollToSelected()
    }

    public func navigatePrevious() {
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + filteredWindows.count) % filteredWindows.count
        updateSelection()
        scrollToSelected()
    }

    public func selectCurrent() -> ScreenWindow? {
        guard !filteredWindows.isEmpty, selectedIndex < filteredWindows.count else { return nil }
        return filteredWindows[selectedIndex]
    }

    // MARK: - Filtering

    /// Filters a window list by title or app name (case-insensitive).
    /// Extracted as a pure static function so it can be unit-tested without a running UI.
    public static func filter(_ windows: [ScreenWindow], query: String) -> [ScreenWindow] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return windows }
        return windows.filter {
            $0.title.lowercased().contains(q) || $0.appName.lowercased().contains(q)
        }
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        filteredWindows = SwitcherPanel.filter(windows, query: sender.stringValue)
        selectedIndex = 0
        collectionView.reloadData()
        updateSelection()
    }

    // MARK: - Selection helpers

    private func updateSelection() {
        guard !filteredWindows.isEmpty, selectedIndex < filteredWindows.count else { return }
        collectionView.selectItems(at: [IndexPath(item: selectedIndex, section: 0)], scrollPosition: [])
    }

    private func scrollToSelected() {
        guard !filteredWindows.isEmpty, selectedIndex < filteredWindows.count else { return }
        collectionView.scrollToItems(at: [IndexPath(item: selectedIndex, section: 0)], scrollPosition: .centeredHorizontally)
    }
}

// MARK: - NSCollectionView DataSource & Delegate

extension SwitcherPanel: NSCollectionViewDataSource, NSCollectionViewDelegate {
    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredWindows.count
    }

    public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: SwitcherCell.identifier,
            for: indexPath
        ) as! SwitcherCell
        item.configure(with: filteredWindows[indexPath.item])
        return item
    }

    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        selectedIndex = indexPath.item
        onWindowSelected?(filteredWindows[selectedIndex])
    }
}
