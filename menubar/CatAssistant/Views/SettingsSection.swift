import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct AmberSegmentedPicker<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = selection == option.value
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                        .foregroundStyle(isSelected ? Color.segmentActiveText : Color.segmentText)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? Color.amber : Color.clear))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(2).background(Color.segmentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct SettingsSection: View {
    @ObservedObject var updater: UpdaterBase
    @ObservedObject var licenseManager: LicenseManager
    @ObservedObject var pluginManager: PluginManager
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("desktopPetsEnabled") private var desktopPetsEnabled = true
    @AppStorage("desktopPetSize") private var desktopPetSize = 64
    @State private var disabledPetSources: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "disabledPetSources") ?? [])
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var justInstalled = false
    @State private var installFailed = false
    @State private var removeHovered = false
    @State private var copilotJustInstalled = false
    @State private var copilotInstallFailed = false
    @State private var copilotRemoveHovered = false

    var body: some View {
        VStack(spacing: 0) {
            LicenseSection(licenseManager: licenseManager)
            Divider().padding(.horizontal, 14)
            updateSection
            MonitoredToolsView(
                pluginManager: pluginManager,
                justInstalled: $justInstalled,
                installFailed: $installFailed,
                removeHovered: $removeHovered,
                copilotJustInstalled: $copilotJustInstalled,
                copilotInstallFailed: $copilotInstallFailed,
                copilotRemoveHovered: $copilotRemoveHovered
            )
            Divider().padding(.horizontal, 14)
            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                AmberSegmentedPicker(
                    options: AppearanceMode.allCases.map { ($0.rawValue, $0.label) },
                    selection: $appearanceMode
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 14)

            HStack {
                Text("Toggle Shortcut")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                KeyboardShortcuts.Recorder("", name: .togglePanel)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Refocus Shortcut")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .refocus)
                }
                Text("Bring up the panel and jump to sessions by number.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 14)

            Toggle(isOn: $launchAtLogin) {
                Text("Launch at Login")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .onChange(of: launchAtLogin) { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }

            Divider().padding(.horizontal, 14)

            Toggle(isOn: $notificationsEnabled) {
                Text("Notifications")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .onChange(of: notificationsEnabled) { newValue in
                if newValue {
                    SessionManager.requestNotificationPermission()
                }
            }

            Divider().padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $desktopPetsEnabled) {
                    Text("Desktop Pets")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                if desktopPetsEnabled {
                    HStack {
                        Text("Pet Size")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        AmberSegmentedPicker(
                            options: [
                                (48, "Small"),
                                (64, "Medium"),
                                (96, "Large"),
                            ],
                            selection: $desktopPetSize
                        )
                        .frame(width: 180)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Pets For")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                        HStack(spacing: 6) {
                            ForEach(sourceToggleOptions, id: \.key) { option in
                                petSourceToggle(option.key, label: option.label)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color.settingsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.settingsBorder, lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var updateSection: some View {
        if let version = updater.pendingUpdateVersion {
            Button {
                updater.checkForUpdates()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.amber)
                    Text("Update available: v\(version)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Install v\(version)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.amber)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            Divider().padding(.horizontal, 14)
        } else if let reason = updater.disabledReason {
            disabledSection(reason: reason)
            Divider().padding(.horizontal, 14)
        } else if updater.canCheckForUpdates {
            updateControlsSection
            Divider().padding(.horizontal, 14)
        }
    }

    private var currentVersion: String { Bundle.main.appVersion }

    private var updateControlsSection: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Up to date \u{2014} v\(currentVersion)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                updater.checkForUpdates()
            } label: {
                Text("Check for Updates")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func disabledSection(reason: DisabledReason) -> some View {
        Text(reason.reasonText)
            .font(.system(size: 10))
            .foregroundStyle(Color.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
    }

    // MARK: - Per-Source Pet Toggles

    private struct SourceToggleOption: Identifiable {
        let key: String   // UserDefaults key: "claude", "copilot", "opencode", "cli"
        let label: String // Display label: "CC", "CP", "OC", "CLI"
        var id: String { key }
    }

    private var sourceToggleOptions: [SourceToggleOption] {
        [
            SourceToggleOption(key: "claude", label: "CC"),
            SourceToggleOption(key: "copilot", label: "CP"),
            SourceToggleOption(key: "opencode", label: "OC"),
            SourceToggleOption(key: "cli", label: "CLI"),
        ]
    }

    private func petSourceToggle(_ sourceKey: String, label: String) -> some View {
        let isEnabled = !disabledPetSources.contains(sourceKey)
        return Button {
            var sources = disabledPetSources
            if isEnabled {
                sources.insert(sourceKey)
            } else {
                sources.remove(sourceKey)
            }
            disabledPetSources = sources
            UserDefaults.standard.set(Array(sources), forKey: "disabledPetSources")
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.segmentActiveText : Color.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isEnabled ? Color.amber : Color.segmentBackground)
                )
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Monitored Tools

private struct MonitoredToolsView: View {
    @ObservedObject var pluginManager: PluginManager
    @Binding var justInstalled: Bool
    @Binding var installFailed: Bool
    @Binding var removeHovered: Bool
    @Binding var copilotJustInstalled: Bool
    @Binding var copilotInstallFailed: Bool
    @Binding var copilotRemoveHovered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monitored Tools")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            toolRow(name: "Claude Code", installed: pluginManager.ccInstalled)
            if pluginManager.ocConfigExists {
                openCodeRow
            }
            if pluginManager.vscodeExists {
                copilotRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var openCodeRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                toolLabel("opencode")
                Spacer()
                if justInstalled {
                    EmptyView()
                } else if pluginManager.ocInstalled {
                    connectedBadge
                    Button {
                        if !pluginManager.removeOpenCodePlugin() {
                            flashFailed()
                        }
                    } label: {
                        Text("Remove")
                            .font(.system(size: 10))
                            .foregroundStyle(removeHovered ? Color.primary : Color.textMuted)
                    }
                    .buttonStyle(.plain)
                    .onHover { removeHovered = $0 }
                } else {
                    installPluginButton
                }
            }
            if justInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("Installed \u{2014} restart opencode to start tracking")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
                .transition(.opacity)
            }
            if installFailed {
                Text("Failed \u{2014} check permissions")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.amber)
                    .transition(.opacity)
            }
        }
    }

    private var copilotRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                toolLabel("VS Code Copilot")
                Spacer()
                if copilotJustInstalled {
                    EmptyView()
                } else if pluginManager.copilotInstalled {
                    connectedBadge
                    Button {
                        if !pluginManager.removeCopilotHooks() {
                            flashCopilotFailed()
                        }
                    } label: {
                        Text("Remove")
                            .font(.system(size: 10))
                            .foregroundStyle(copilotRemoveHovered ? Color.primary : Color.textMuted)
                    }
                    .buttonStyle(.plain)
                    .onHover { copilotRemoveHovered = $0 }
                } else {
                    copilotInstallButton
                }
            }
            if copilotJustInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("Installed \u{2014} restart VS Code to activate")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
                .transition(.opacity)
            }
            if copilotInstallFailed {
                Text("Failed \u{2014} check permissions")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.amber)
                    .transition(.opacity)
            }
        }
    }

    private var installPluginButton: some View {
        Button {
            if pluginManager.installOpenCodePlugin() {
                justInstalled = true
                installFailed = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    justInstalled = false
                }
            } else {
                flashFailed()
            }
        } label: {
            Text("Install Plugin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.segmentActiveText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.amber)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private var copilotInstallButton: some View {
        Button {
            if pluginManager.installCopilotHooks() {
                copilotJustInstalled = true
                copilotInstallFailed = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    copilotJustInstalled = false
                }
            } else {
                flashCopilotFailed()
            }
        } label: {
            Text("Connect")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.segmentActiveText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.amber)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func flashFailed() {
        installFailed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            installFailed = false
        }
    }

    private func flashCopilotFailed() {
        copilotInstallFailed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            copilotInstallFailed = false
        }
    }

    private func toolRow(name: String, installed: Bool) -> some View {
        HStack(spacing: 8) {
            toolLabel(name)
            Spacer()
            if installed {
                connectedBadge
            } else {
                Text("Not installed")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textMuted)
            }
        }
    }

    private func toolLabel(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 16, height: 16)
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    private var connectedBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.statusGreen)
                .frame(width: 6, height: 6)
            Text("Connected")
                .font(.system(size: 10))
                .foregroundStyle(Color.textMuted)
        }
    }
}

// MARK: - License Section

private struct LicenseSection: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var showKeyEntry = false
    @State private var licenseKeyInput = ""
    @State private var emailInput = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var purchaseHovered = false
    @State private var enterKeyHovered = false
    @State private var deactivateHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if licenseManager.status.isLicensed {
                licensedView
            } else if showKeyEntry {
                keyEntryView
            } else {
                unlicensedView
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Licensed

    private var licensedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.amber)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("Licensed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                if let email = licenseManager.status.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
            }
            Spacer()
            Button {
                licenseManager.deactivate()
            } label: {
                Text("Deactivate")
                    .font(.system(size: 10))
                    .foregroundStyle(deactivateHovered ? Color.primary : Color.textMuted)
            }
            .buttonStyle(.plain)
            .onHover { deactivateHovered = $0 }
        }
    }

    // MARK: - Unlicensed

    private var unlicensedView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unlicensed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Text("All features available \u{2014} no limits")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textMuted)
            }
            Spacer()
            Button {
                licenseManager.openPurchasePage()
            } label: {
                Text("Purchase")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.segmentActiveText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.amber)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showKeyEntry = true }
            } label: {
                Text("Enter Key")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(enterKeyHovered ? Color.primary : Color.textMuted)
                    .underline(enterKeyHovered)
            }
            .buttonStyle(.plain)
            .onHover { enterKeyHovered = $0 }
        }
    }

    // MARK: - Key Entry

    private var keyEntryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Enter License Key")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showKeyEntry = false
                        errorMessage = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
            }

            TextField("CA-XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .onChange(of: licenseKeyInput) { _ in errorMessage = nil }

            TextField("Email (optional)", text: $emailInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Button {
                        activateKey()
                    } label: {
                        Text("Activate")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.segmentActiveText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.amber)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func activateKey() {
        let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isValidating = true
        errorMessage = nil
        Task {
            let result = await licenseManager.activate(
                licenseKey: key,
                email: emailInput.isEmpty ? nil : emailInput
            )
            isValidating = false
            switch result {
            case .success:
                withAnimation(.easeInOut(duration: 0.15)) {
                    showKeyEntry = false
                    licenseKeyInput = ""
                    emailInput = ""
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview Helpers

@MainActor private class MockUpdater: UpdaterBase {
    override var canCheckForUpdates: Bool { true }
}
@MainActor private func previewPM(
    cc: Bool = true, oc: Bool = false, ocConfig: Bool = false,
    copilot: Bool = false, vscode: Bool = false
) -> PluginManager {
    let pm = PluginManager()
    pm.ccInstalled = cc
    pm.ocInstalled = oc
    pm.ocConfigExists = ocConfig
    pm.copilotInstalled = copilot
    pm.vscodeExists = vscode
    return pm
}
#Preview("Default") {
    SettingsSection(updater: DisabledUpdater(), licenseManager: LicenseManager.shared, pluginManager: previewPM()).frame(width: 320).padding()
}
#Preview("Update available") {
    let up = DisabledUpdater(); up.pendingUpdateVersion = "0.7.0"
    return SettingsSection(updater: up, licenseManager: LicenseManager.shared, pluginManager: previewPM()).frame(width: 320).padding()
}
#Preview("OC detected") {
    SettingsSection(updater: DisabledUpdater(), licenseManager: LicenseManager.shared, pluginManager: previewPM(ocConfig: true)).frame(width: 320).padding()
}
#Preview("Both connected") {
    SettingsSection(updater: DisabledUpdater(), licenseManager: LicenseManager.shared, pluginManager: previewPM(oc: true, ocConfig: true)).frame(width: 320).padding()
}
#Preview("Sparkle: update available") {
    let mock = MockUpdater(); mock.pendingUpdateVersion = "0.7.0"
    return SettingsSection(updater: mock, licenseManager: LicenseManager.shared, pluginManager: previewPM()).frame(width: 320).padding()
}
#Preview("Sparkle: up to date") {
    SettingsSection(updater: MockUpdater(), licenseManager: LicenseManager.shared, pluginManager: previewPM()).frame(width: 320).padding()
}
