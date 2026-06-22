import AppKit
import ApplicationServices

/// Manages macOS privacy permissions (Accessibility, Screen Recording).
public final class PermissionsManager {

    public static let shared = PermissionsManager()

    private init() {}

    // MARK: - Accessibility

    public var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        guard !hasAccessibilityPermission else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        openPrivacyPane(.accessibility)
        startPollingForAccessibility()
    }

    // Polls every second until Accessibility is granted, then relaunches.
    // macOS requires a full process restart for AXIsProcessTrusted() to flip.
    public func startPollingForAccessibility() {
        guard !hasAccessibilityPermission else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard AXIsProcessTrusted() else { return }
            t.invalidate()
            self?.relaunchForAccessibility()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func relaunchForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Permiso concedido"
        alert.informativeText = "ScreenOS debe reiniciarse para activar el control de ventanas."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reiniciar ahora")
        alert.runModal()
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
        NSApp.terminate(nil)
    }

    // MARK: - Screen Recording

    public var hasScreenRecordingPermission: Bool {
        // Test by attempting a 1×1 capture; nil means permission is denied.
        let testImage = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        )
        return testImage != nil
    }

    public func requestScreenRecordingPermission() {
        guard !hasScreenRecordingPermission else { return }

        // Triggering a capture is the only way to prompt the system dialog.
        DispatchQueue.global().async {
            _ = CGWindowListCreateImage(
                CGRect(x: 0, y: 0, width: 1, height: 1),
                .optionOnScreenOnly,
                kCGNullWindowID,
                .nominalResolution
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.openPrivacyPane(.screenRecording)
        }
    }

    // MARK: - Helpers

    private enum PrivacyPane: String {
        case accessibility = "Privacy_Accessibility"
        case screenRecording = "Privacy_ScreenCapture"
    }

    private func openPrivacyPane(_ pane: PrivacyPane) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Verifies all needed permissions and optionally shows an alert.
    /// - Returns: `true` if all required permissions are granted.
    @discardableResult
    public func verifyPermissions(showAlert: Bool = false) -> Bool {
        let hasAll = hasAccessibilityPermission && hasScreenRecordingPermission
        guard showAlert, !hasAll else { return hasAll }

        if !hasAccessibilityPermission {
            showPermissionAlert(
                title: "Accessibility Permission Required",
                message: "ScreenOS needs Accessibility permission to move and resize windows in other applications.\n\n1. Click \"Open Settings\"\n2. Add ScreenOS to the list\n3. Enable the checkbox next to ScreenOS",
                pane: .accessibility
            )
            return false
        }

        return hasAll
    }

    private func showPermissionAlert(title: String, message: String, pane: PrivacyPane) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            openPrivacyPane(pane)
        }
    }
}
