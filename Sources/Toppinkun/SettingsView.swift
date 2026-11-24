import SwiftUI
import AppKit
import Carbon.HIToolbox
import KunAppKit
import ToppinkunCore

/// 設定ダイアログの編集状態。変更は即時反映する（Apply/OK は持たない）。
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: ToppinkunCore.Settings {
        didSet {
            guard settings != oldValue else { return }
            onChange(settings)
        }
    }
    private let onChange: (ToppinkunCore.Settings) -> Void

    init(settings: ToppinkunCore.Settings, onChange: @escaping (ToppinkunCore.Settings) -> Void) {
        self.settings = settings
        self.onChange = onChange
    }
}

/// 設定ダイアログ本体。タブで機能ごとの設定を切り替える。各変更は即座に反映・保存される。
/// 「一般」タブ（自動起動・バージョン）は左端に置き、機能追加時はタブを右へ足す。
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var loginItem: LoginItemController

    @State private var loginItemError: String?

    var body: some View {
        TabView {
            GeneralSettingsTab(loginItem: loginItem, errorMessage: $loginItemError)
                .tabItem { Text(L.string("tab.general")) }

            PinSettingsTab(settings: $viewModel.settings.pin)
                .tabItem { Text(L.string("tab.pin")) }
        }
        .padding()
        .frame(width: 520, height: 380)
        .alert(L.string("alert.error.title"), isPresented: Binding(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError ?? "")
        }
    }
}

/// 「一般」タブ。ログイン時の自動起動とバージョン表示。
struct GeneralSettingsTab: View {
    @ObservedObject var loginItem: LoginItemController
    @SwiftUI.Binding var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(L.string("settings.launch_at_login"), isOn: Binding(
                get: { loginItem.isEnabled },
                set: { newValue in
                    if let message = loginItem.setEnabled(newValue) {
                        errorMessage = message
                    }
                }
            ))

            Text(L.format("settings.version", UpdateService.currentVersion))
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 「固定」タブ。固定/解除のホットキーと、必要な権限の状態。
struct PinSettingsTab: View {
    @SwiftUI.Binding var settings: PinSettings

    @State private var hasScreenCapture = Permissions.hasScreenCapture
    @State private var hasAccessibility = Permissions.hasAccessibility

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(L.string("pin.hotkey"))
                Spacer(minLength: 12)
                HotKeyRecorderView(config: $settings.hotKey)
            }

            PermissionRow(
                title: L.string("permission.screen_capture"),
                granted: hasScreenCapture,
                action: {
                    Permissions.requestScreenCapture()
                    Permissions.openScreenCaptureSettings()
                }
            )
            PermissionRow(
                title: L.string("permission.accessibility"),
                granted: hasAccessibility,
                action: {
                    Permissions.requestAccessibility()
                    Permissions.openAccessibilitySettings()
                }
            )

            Text(L.string("pin.description"))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // システム設定で許可して戻ってきたときに表示を更新する。
            hasScreenCapture = Permissions.hasScreenCapture
            hasAccessibility = Permissions.hasAccessibility
        }
    }
}

/// 権限1件の状態表示と、未許可時の「許可…」ボタン。
private struct PermissionRow: View {
    let title: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 12)
            if granted {
                Text(L.string("permission.granted")).foregroundColor(.secondary)
            } else {
                Button(L.string("permission.grant"), action: action)
            }
        }
    }
}

/// ホットキーを記録するボタン。押下後に次のキー入力（修飾キー必須）を取り込む。
struct HotKeyRecorderView: View {
    @SwiftUI.Binding var config: HotKeyConfig
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? L.string("hotkey.recording") : config.displayString)
                .frame(minWidth: 120)
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        if isRecording { stop() } else { start() }
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc（修飾なし）で記録をキャンセル。
            if event.keyCode == UInt16(kVK_Escape),
               event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                stop()
                return nil
            }
            // 修飾キーが付いていれば確定。無ければ記録継続（誤爆防止）。
            if let newConfig = HotKeyTranslation.config(from: event) {
                config = newConfig
                stop()
            }
            return nil // 記録中はイベントを消費する。
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
