import AppKit

/// The overlay panel shown when the window switcher is active.
/// Displays a horizontal strip of window thumbnails with app icons and titles.
final class SwitcherPanel: NSWindow {

    // MARK: - UI Constants

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

    var onWindowSelected: ((ScreenWindow) -> Void)?

    // MARK: - Init

    init() {
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
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false

        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Container view with rounded rect background
        let containerFrame = self.contentRect(forFrameRect: self.frame)
        let containerView = NSView(frame: containerFrame)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Layout.cornerRadius
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor

        contentView = containerView

        // Search field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filtrar ventanas..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.bezelStyle = .roundedBezel
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        containerView.addSubview(searchField)

        // Collection view inside scroll view
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SwitcherCell.self, forItemWithIdentifier: SwitcherCell.identifier)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        containerView.addSubview(scrollView)

        // Constraints
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        // Visual effect for blur behind
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        visualEffect.blendingMode = NSVisualEffectView.BlendingMode.behindWindow
        visualEffect.material = NSVisualEffectView.Material.hudWindow
        visualEffect.state = NSVisualEffectView.State.active
        containerView.addSubview(visualEffect, positioned: NSWindow.OrderingMode.below, relativeTo: nil as NSView?)
    }

    // MARK: - Public

    func show(with windows: [ScreenWindow]) {
        self.windows = windows
        filteredWindows = windows
        selectedIndex = 0
        searchField.stringValue = ""

        collectionView.reloadData()
        updateSelection()

        makeKeyAndOrderFront(nil)
    }

    func closePanel() {
        orderOut(nil)
    }

    func navigateNext() {
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % filteredWindows.count
        updateSelection()
        scrollToSelected()
    }

    func navigatePrevious() {
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + filteredWindows.count) % filteredWindows.count
        updateSelection()
        scrollToSelected()
    }

    func selectCurrent() -> ScreenWindow? {
        guard !filteredWindows.isEmpty, selectedIndex < filteredWindows.count else { return nil }
        return filteredWindows[selectedIndex]
    }

    // MARK: - Actions

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        let query = sender.stringValue.lowercased().trimmingCharacters(in: .whitespaces)

        if query.isEmpty {
            filteredWindows = windows
        } else {
            filteredWindows = windows.filter { window in
                window.title.lowercased().contains(query) ||
                window.appName.lowercased().contains(query)
            }
        }

        selectedIndex = 0
        collectionView.reloadData()
        updateSelection()
    }

    // MARK: - Selection

    private func updateSelection() {
        guard !filteredWindows.isEmpty, selectedIndex < filteredWindows.count else { return }
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        collectionView.selectItems(at: [indexPath], scrollPosition: [])
    }

    private func scrollToSelected() {
        guard !filteredWindows.isEmpty, selectedIndex < filteredWindows.count else { return }
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredHorizontally)
    }
}

// MARK: - NSCollectionView DataSource & Delegate

extension SwitcherPanel: NSCollectionViewDataSource, NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredWindows.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: SwitcherCell.identifier,
            for: indexPath
        ) as! SwitcherCell
        item.configure(with: filteredWindows[indexPath.item])
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        selectedIndex = indexPath.item
        let window = filteredWindows[selectedIndex]
        onWindowSelected?(window)
    }
}
