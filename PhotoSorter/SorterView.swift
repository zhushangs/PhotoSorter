import Photos
import SwiftUI

struct SorterView: View {
    @EnvironmentObject var model: SorterModel
    @State private var showManager = false
    @State private var drag: CGSize = .zero
    @State private var openAlbum: AlbumItem?

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                if model.isLoading {
                    ProgressView("正在读取照片…")
                } else if let asset = model.current {
                    AssetImageView(asset: asset)
                        .id(asset.localIdentifier)
                        .offset(drag)
                        .rotationEffect(.degrees(Double(drag.width / 25)))
                        .gesture(swipe)
                        .overlay { swipeHint }
                        .padding(.horizontal, 30)   // room for the side arrows
                } else {
                    doneView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .leading) {
                SideArrow(systemImage: "chevron.left", label: "返回上一步",
                          enabled: model.canUndo && !model.isLoading) {
                    model.undo()
                }
            }
            .overlay(alignment: .trailing) {
                SideArrow(systemImage: "chevron.right", label: "略过这张",
                          enabled: model.current != nil && !model.isLoading) {
                    model.skip()
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)

            AlbumBar(
                enabled: model.current != nil,
                onAdd: { showManager = true },
                onTap: { model.file(into: $0.id) },
                onOpen: { openAlbum = $0 }
            )
        }
        .overlay(alignment: .top) { ToastOverlay() }
        .sheet(isPresented: $showManager, onDismiss: { model.resortBar() }) {
            AlbumManagerView().environmentObject(model)
        }
        .sheet(item: $openAlbum, onDismiss: { model.resortBar() }) { album in
            NavigationStack {
                AlbumDetailView(albumID: album.id, showsCloseButton: true)
            }
            .environmentObject(model)
        }
        .alert(
            "没保存成功",
            isPresented: Binding(
                get: { model.saveError != nil },
                set: { if !$0 { model.saveError = nil } }
            )
        ) {
            Button("知道了", role: .cancel) { model.saveError = nil }
        } message: {
            Text(model.saveError ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            Menu {
                Button {
                    Task { await model.reload() }
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                Picker("顺序", selection: $model.newestFirst) {
                    Text("从最新的开始").tag(true)
                    Text("从最旧的开始").tag(false)
                }
                Button {
                    showManager = true
                } label: {
                    Label("管理相册", systemImage: "rectangle.stack")
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title2)
            }

            Spacer()

            VStack(spacing: 2) {
                if model.savingCount > 0 {
                    Label("保存中…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("未分类").font(.caption).foregroundStyle(.secondary)
                }
                Text("还剩 \(model.remaining) 张").font(.headline)
            }

            Spacer()

            // Tap = mark this photo for deletion. Long-press = delete all / restore all.
            Menu {
                Section("\(model.pendingDelete.count) 张照片等着删除") {
                    Button(role: .destructive) {
                        Task { await model.commitDeletes() }
                    } label: {
                        Label("全部删除", systemImage: "trash")
                    }
                    Button {
                        Task { await model.clearPendingDeletes() }
                    } label: {
                        Label("全部恢复", systemImage: "arrow.uturn.backward")
                    }
                }
                .disabled(model.pendingDelete.isEmpty)
            } label: {
                Image(systemName: "trash.circle")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .overlay(alignment: .topTrailing) {
                        if !model.pendingDelete.isEmpty {
                            Text("\(model.pendingDelete.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.red, in: Capsule())
                                .offset(x: 9, y: -7)
                        }
                    }
            } primaryAction: {
                model.markDelete()
            }
            .disabled(model.isLoading)
            .accessibilityLabel("删除这张照片，长按处理全部待删除")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: Swipe (left = 略过, right = 返回, up = 删除)

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                let t = value.translation
                // Tie the action to the photo the swipe started on.
                let id = model.current?.localIdentifier
                if t.height < -110 && abs(t.height) > abs(t.width) {
                    flyOut(to: CGSize(width: 0, height: -900)) { model.markDelete(expecting: id) }
                } else if t.width < -100 {
                    flyOut(to: CGSize(width: -600, height: t.height)) { model.skip(expecting: id) }
                } else if t.width > 100 && model.canUndo {
                    withAnimation(.spring(duration: 0.25)) { drag = .zero }
                    model.undo()
                } else {
                    withAnimation(.spring(duration: 0.25)) { drag = .zero }
                }
            }
    }

    private func flyOut(to target: CGSize, then action: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.15)) { drag = target }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            drag = .zero
            action()
        }
    }

    @ViewBuilder
    private var swipeHint: some View {
        if drag.height < -50 && abs(drag.height) > abs(drag.width) {
            hintLabel("删除", systemImage: "trash", color: .red)
        } else if drag.width < -50 {
            hintLabel("略过", systemImage: "chevron.right", color: .gray)
        } else if drag.width > 50 && model.canUndo {
            hintLabel("返回", systemImage: "chevron.left", color: .blue)
        }
    }

    private func hintLabel(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(color.opacity(0.85), in: Capsule())
    }

    // MARK: Done

    private var doneView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("全部整理完了").font(.title2.bold())
            Text("略过的照片下次重新扫描时还会出现。")
                .foregroundStyle(.secondary)
            Button("重新扫描") {
                Task { await model.reload() }
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Side arrows

private struct SideArrow: View {
    let systemImage: String
    let label: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08)))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .buttonStyle(PressScaleStyle())
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

// MARK: - Album bar

/// Card-style album chips (cover + name + count) in two scrollable rows.
/// Tap = onTap; long-press menu offers open / remove from bar.
struct AlbumBar: View {
    @EnvironmentObject var model: SorterModel
    var excluding: String? = nil
    var enabled: Bool = true
    var onAdd: (() -> Void)? = nil
    var onTap: (AlbumItem) -> Void
    var onOpen: ((AlbumItem) -> Void)? = nil

    private static let chipHeight: CGFloat = 50
    private let rows = [
        GridItem(.fixed(Self.chipHeight), spacing: 8),
        GridItem(.fixed(Self.chipHeight), spacing: 8),
    ]

    private var shown: [AlbumItem] {
        model.barAlbums.filter { $0.id != excluding }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            HStack {
                Text("放入相册")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let onAdd {
                    Button(action: onAdd) {
                        Label("管理", systemImage: "slider.horizontal.3")
                            .font(.footnote.weight(.medium))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            if shown.isEmpty {
                Button {
                    onAdd?()
                } label: {
                    Label("添加相册到这里", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Self.chipHeight * 2 + 8)
                }
                .disabled(onAdd == nil)
                .padding(.bottom, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: 8) {
                        ForEach(shown) { album in
                            Button {
                                onTap(album)
                            } label: {
                                AlbumChip(album: album)
                            }
                            .buttonStyle(PressScaleStyle())
                            .opacity(enabled ? 1 : 0.45)
                            .disabled(!enabled)
                            .contextMenu {
                                if let onOpen {
                                    Button {
                                        onOpen(album)
                                    } label: {
                                        Label("打开相册", systemImage: "photo.on.rectangle")
                                    }
                                }
                                Button(role: .destructive) {
                                    model.removeFromBar(album.id)
                                } label: {
                                    Label("从相册栏移除", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .frame(height: Self.chipHeight * 2 + 8 + 20)
            }
        }
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct AlbumChip: View {
    let album: AlbumItem

    var body: some View {
        HStack(spacing: 9) {
            cover
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(album.count) 张")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(minWidth: 120, maxWidth: 176, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        )
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    @ViewBuilder
    private var cover: some View {
        if let asset = album.cover {
            ThumbnailView(asset: asset)
                .id(asset.localIdentifier)
        } else {
            ZStack {
                Color.secondary.opacity(0.12)
                Image(systemName: "photo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Slight shrink while pressed — makes taps feel responsive.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}
