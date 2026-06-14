import AppKit

/// A collection view cell that displays a window thumbnail, app icon, and title.
public final class SwitcherCell: NSCollectionViewItem {

    public static let identifier = NSUserInterfaceItemIdentifier("SwitcherCell")

    // MARK: - UI Elements

    private let thumbnailView: NSImageView = {
        let iv = NSImageView()
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 6
        iv.layer?.masksToBounds = true
        iv.imageScaling = .scaleAxesIndependently
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let appIconView: NSImageView = {
        let iv = NSImageView()
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 4
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        tf.textColor = .labelColor
        tf.lineBreakMode = .byTruncatingTail
        tf.alignment = .center
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let appNameLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.systemFont(ofSize: 10)
        tf.textColor = .secondaryLabelColor
        tf.lineBreakMode = .byTruncatingTail
        tf.alignment = .center
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let selectionBorder: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 8
        v.layer?.borderWidth = 2.5
        v.layer?.borderColor = NSColor.controlAccentColor.cgColor
        v.layer?.opacity = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Lifecycle

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(selectionBorder)
        view.addSubview(thumbnailView)
        view.addSubview(appIconView)
        view.addSubview(titleLabel)
        view.addSubview(appNameLabel)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            thumbnailView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            thumbnailView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            thumbnailView.heightAnchor.constraint(equalTo: thumbnailView.widthAnchor, multiplier: 0.75),

            appIconView.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 8),
            appIconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 20),
            appIconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: appIconView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),

            appNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            appNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            appNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),

            selectionBorder.topAnchor.constraint(equalTo: view.topAnchor),
            selectionBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectionBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            selectionBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    public override var isSelected: Bool {
        didSet {
            selectionBorder.layer?.opacity = isSelected ? 1.0 : 0.0
            view.layer?.backgroundColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
                : nil
        }
    }

    // MARK: - Configuration

    public func configure(with window: ScreenWindow) {
        titleLabel.stringValue = window.title
        appNameLabel.stringValue = window.appName
        appIconView.image = window.appIcon
        thumbnailView.image = nil
        loadThumbnail(for: window)
    }

    private func loadThumbnail(for window: ScreenWindow) {
        let windowID = window.id
        let frame = window.frame

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let imageRef = CGWindowListCreateImage(
                frame,
                [.optionIncludingWindow],
                windowID,
                .nominalResolution
            )
            DispatchQueue.main.async {
                guard let self, let imageRef else { return }
                // Only update if the cell hasn't been reused for a different window
                if self.titleLabel.stringValue == window.title {
                    self.thumbnailView.image = NSImage(cgImage: imageRef, size: frame.size)
                }
            }
        }
    }
}
