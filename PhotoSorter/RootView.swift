import Photos
import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: SorterModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.authStatus {
            case .authorized:
                SorterView()
            case .notDetermined:
                MessageView(
                    icon: "photo.stack",
                    title: "整理你的照片",
                    message: "理片会显示所有还没放进相册的照片，点一下底部的相册名就能归档。照片只在你手机上处理，不上传任何地方。",
                    buttonTitle: "允许访问照片"
                ) {
                    Task { await model.requestAccess() }
                }
            case .limited:
                MessageView(
                    icon: "exclamationmark.lock",
                    title: "需要“完全访问”",
                    message: "现在只允许访问部分照片，这样读不到你的相册。请在设置里把照片权限改成“完全访问”。",
                    buttonTitle: "打开设置",
                    action: openSettings
                )
            default:
                MessageView(
                    icon: "lock",
                    title: "没有照片权限",
                    message: "请在设置里允许理片访问照片（选“完全访问”）。",
                    buttonTitle: "打开设置",
                    action: openSettings
                )
            }
        }
        .task {
            if model.authStatus == .authorized && model.queue.isEmpty {
                await model.reload()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from Settings after changing the permission.
            guard phase == .active else { return }
            let before = model.authStatus
            model.refreshAuthStatus()
            if before != .authorized && model.authStatus == .authorized {
                Task { await model.reload() }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct MessageView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title).font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding(32)
    }
}
