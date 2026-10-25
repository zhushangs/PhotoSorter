import Photos
import SwiftUI

struct SorterView: View {
    @EnvironmentObject var model: SorterModel
    @State private var showManager = false
    @State private var showDeleteDialog = false
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
                } else {
                    doneView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            actionRow
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
        .confirmationDialog(
            "有 \(model.pendingDelete.count) 张照片等着删除",
            isPresented: $showDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("全部删除", role: .destructive) {
                Task { await model.commitDeletes() }
            }
            Button("全部恢复（不删了）") {
                Task { await model.clearPendingDeletes() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后会进入系统相册的“最近删除”，30 天内都能找回。")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                model.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.title2)
            }
            .disabled(!model.canUndo)

            Spacer()

            VStack(spacing: 2) {
                Text("未分类").font(.caption).foregroundStyle(.secondary)
                Text("还剩 \(model.remaining) 张").font(.headline)
            }

            Spacer()

            Button {
                showDeleteDialog = true
            } label: {
                Image(systemName: "trash.circle")
                    .font(.title2)
                    .overlay(alignment: .topTrailing) {
                        if !model.pendingDelete.isEmpty {
                            Text("\(model.pendingDelete.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.red, in: Capsule())
                                .offset(x: 8, y: -6)
                        }
                    }
            }
            .disabled(model.pendingDelete.isEmpty)

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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: Swipe

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                let t = value.translation
                if t.height < -110 && abs(t.height) > abs(t.width) {
                    flyOut(to: CGSize(width: 0, height: -900)) { model.markDelete() }
                } else if t.width < -100 {
                    flyOut(to: CGSize(width: -600, height: t.height)) { model.skip() }
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
            hintLabel("跳过", systemImage: "arrow.left", color: .gray)
        } else if drag.width > 50 && model.canUndo {
            hintLabel("上一张", systemImage: "arrow.uturn.backward", color: .blue)
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

    // MARK: Buttons under the photo

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                model.markDelete()
            } label: {
                Label("删除", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                model.skip()
            } label: {
                Label("跳过", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .disabled(model.current == nil)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: Done / toast

    private var doneView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("全部整理完了").font(.title2.bold())
            Text("跳过的照片下次重新扫描时还会出现。")
                .foregroundStyle(.secondary)
            Button("重新扫描") {
                Task { await model.reload() }
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Album bar

/// Two rows of album chips. Tap = onTap; long-press menu offers open / remove from bar.
struct AlbumBar: View {
    @EnvironmentObject var model: SorterModel
    var excluding: String? = nil
    var enabled: Bool = true
    var onAdd: (() -> Void)? = nil
    var onTap: (AlbumItem) -> Void
    var onOpen: ((AlbumItem) -> Void)? = nil

    private let rows = [
        GridItem(.fixed(46), spacing: 8),
        GridItem(.fixed(46), spacing: 8),
    ]

    private var shown: [AlbumItem] {
        model.barAlbums.filter { $0.id != excluding }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if shown.isEmpty {
                Button {
                    onAdd?()
                } label: {
                    Label("添加相册到这里", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .disabled(onAdd == nil)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: 8) {
                        if let onAdd {
                            Button(action: onAdd) {
                                Image(systemName: "plus")
                                    .font(.headline)
                                    .frame(width: 46)
                                    .frame(maxHeight: .infinity)
                                    .background(Color.secondary.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        ForEach(shown) { album in
                            Button {
                                onTap(album)
                            } label: {
                                AlbumChip(album: album)
                            }
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(height: 46 * 2 + 8 + 20)
            }
        }
        .background(.bar)
    }
}

struct AlbumChip: View {
    let album: AlbumItem

    var body: some View {
        VStack(spacing: 1) {
            Text(album.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(album.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(minWidth: 76)
        .frame(maxHeight: .infinity)
        .background(Color.accentColor.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(.primary)
    }
}
