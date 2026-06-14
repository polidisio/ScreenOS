import AppKit

/// Preferences window showing customizable hotkey mappings.
public final class PreferencesViewController: NSViewController {

    // MARK: - Data

    private struct ShortcutItem {
        let label: String
        let key: String
        var shortcut: ShortcutRecorder.Shortcut?
    }

    private var items: [ShortcutItem] = [
        ShortcutItem(label: "Show Desktop",    key: "hotkey-showDesktop"),
        ShortcutItem(label: "Tile Left",       key: "hotkey-tileLeft"),
        ShortcutItem(label: "Tile Right",      key: "hotkey-tileRight"),
        ShortcutItem(label: "Tile Top",        key: "hotkey-tileTop"),
        ShortcutItem(label: "Tile Bottom",     key: "hotkey-tileBottom"),
        ShortcutItem(label: "Tile Top-Left",   key: "hotkey-tileTopLeft"),
        ShortcutItem(label: "Tile Top-Right",  key: "hotkey-tileTopRight"),
        ShortcutItem(label: "Tile Bot-Left",   key: "hotkey-tileBottomLeft"),
        ShortcutItem(label: "Tile Bot-Right",  key: "hotkey-tileBottomRight"),
        ShortcutItem(label: "Maximize",        key: "hotkey-maximize"),
        ShortcutItem(label: "Center",          key: "hotkey-center"),
        ShortcutItem(label: "Window Switcher", key: "hotkey-switcher"),
    ]

    // MARK: - UI

    private let scrollView = NSScrollView()
    private let stackView: NSStackView = {
        let sv = NSStackView()
        sv.orientation = .vertical
        sv.alignment = .leading
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let infoLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "Shortcut changes apply after restarting ScreenOS.")
        tf.font = NSFont.systemFont(ofSize: 11)
        tf.textColor = .secondaryLabelColor
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    // MARK: - Lifecycle

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 460))
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedShortcuts()
    }

    // MARK: - Setup

    private func setupUI() {
        let titleLabel = NSTextField(labelWithString: "Keyboard Shortcuts")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        for (index, item) in items.enumerated() {
            stackView.addArrangedSubview(createRow(for: item, index: index))
            if index < items.count - 1 {
                let sep = NSBox()
                sep.boxType = .separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                stackView.addArrangedSubview(sep)
            }
        }

        stackView.addArrangedSubview(infoLabel)

        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stackView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = wrapper
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        view.addSubview(titleLabel)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            stackView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            wrapper.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            wrapper.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func createRow(for item: ShortcutItem, index: Int) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: item.label)
        label.font = NSFont.systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false

        let recorder = ShortcutRecorder()
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.shortcut = item.shortcut
        recorder.tag = index
        recorder.onShortcutChanged = { [weak self] shortcut in
            self?.saveShortcut(shortcut, at: index)
        }

        let restoreButton = NSButton(title: "↺", target: self, action: #selector(restoreDefault(_:)))
        restoreButton.tag = index
        restoreButton.bezelStyle = .roundRect
        restoreButton.font = NSFont.systemFont(ofSize: 12)
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.toolTip = "Restore default shortcut"

        row.addSubview(label)
        row.addSubview(recorder)
        row.addSubview(restoreButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 140),

            recorder.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            recorder.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            recorder.trailingAnchor.constraint(equalTo: restoreButton.leadingAnchor, constant: -8),
            recorder.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
            recorder.widthAnchor.constraint(equalToConstant: 180),

            restoreButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            restoreButton.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            restoreButton.widthAnchor.constraint(equalToConstant: 28),
            restoreButton.heightAnchor.constraint(equalToConstant: 24),

            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])

        return row
    }

    // MARK: - Persistence

    private func loadSavedShortcuts() {
        let defaults = UserDefaults.standard
        for (index, var item) in items.enumerated() {
            if let data = defaults.data(forKey: item.key),
               let shortcut = try? JSONDecoder().decode(ShortcutRecorder.Shortcut.self, from: data) {
                item.shortcut = shortcut
                items[index] = item
            }
        }
    }

    private func saveShortcut(_ shortcut: ShortcutRecorder.Shortcut, at index: Int) {
        guard index < items.count else { return }
        items[index].shortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: items[index].key)
        }
    }

    @objc private func restoreDefault(_ sender: NSButton) {
        let index = sender.tag
        guard index < items.count else { return }
        items[index].shortcut = nil
        UserDefaults.standard.removeObject(forKey: items[index].key)

        // Rebuild UI to show the reset state
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        setupUI()
        loadSavedShortcuts()
    }
}
