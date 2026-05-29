import AppKit
import ApplicationServices

/// Manages macOS privacy permissions (Accessibility, Screen Recording).
final class PermissionsManager {

    static let shared = PermissionsManager()

    private init() {}

    // MARK: - Accessibility

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        guard !hasAccessibilityPermission else { return }

        // Prompt macOS to show the accessibility permission dialog
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Also open System Settings to the right pane
        openPrivacyPane(.accessibility)
    }

    // MARK: - Screen Recording

    var hasScreenRecordingPermission: Bool {
        // There's no direct API to check Screen Recording permission.
        // We test by trying to capture a tiny image. If it fails, permission is denied.
        let testImage = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        )
        return testImage != nil
    }

    func requestScreenRecordingPermission() {
        guard !hasScreenRecordingPermission else { return }

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

    /// Verifies all needed permissions, shows alerts if missing.
    /// - Parameter showAlert: If true, shows alert. If false, just checks silently.
    /// - Returns: true if all permissions are granted.
    @discardableResult
    func verifyPermissions(showAlert: Bool = false) -> Bool {
        guard showAlert else {
            return hasAccessibilityPermission && hasScreenRecordingPermission
        }

        if !hasAccessibilityPermission {
            showPermissionAlert(
                title: "Permiso de Accesibilidad requerido",
                message: "ScreenOS necesita controlar las ventanas de otras aplicaciones.\n\n" +
                         "1. Haz clic en \"Abrir Preferencias\"\n" +
                         "2. Añade ScreenOS a la lista\n" +
                         "3. Activa el check junto a ScreenOS\n" +
                         "4. Cierra Preferencias del Sistema",
                pane: .accessibility
            )
            return false
        }

        return true
    }

    private func showPermissionAlert(title: String, message: String, pane: PrivacyPane) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Abrir Preferencias")
        alert.addButton(withTitle: "Más tarde")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openPrivacyPane(pane)
        }
        // If "Más tarde", don't terminate - app continues running without that feature
    }
}
