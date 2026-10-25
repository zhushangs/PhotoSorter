import Photos
import SwiftUI

private struct ReviewStart: Identifiable {
    let id = UUID()
    let index: Int
}

/// Grid of the photos in one album. Tap a photo to organize one by one; "选择" for batch actions.
struct AlbumDetailView: View {
    @EnvironmentObject var model: SorterModel
    @Environment(\.dismiss) private var dismiss
    let albumID: String
    let showsCloseButton: Bool

    @State private var assets: [PHAsset] = []
    @State private var selecting = false
    @State private var selected: Set<String> = []
    @State private var showRename = false
    @State private var newName = ""
    @State private var reviewStart: ReviewStart?
    @State private var showMovePicker = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    private var album: AlbumItem? { model.album(albumID) }
    private var selectedAssets: [PHAsset] {
        assets.filter { selected.contains($0.localIdentifier) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { i, asset in
                    ThumbnailView(asset: asset)
                        .overlay(alignment: .topTrailing) {
                            if selecting {
                                let on = selected.contains(asset.localIdentifier)
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(on ? Color.accentColor : .white)
                                    .background(Circle().fill(on ? Color.white : Color.black.opacity(0.2)))
                                    .padding(6)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selecting {
                                toggle(asset)
                            } else {
                                reviewStart = ReviewStart(index: i)
                            }
                        }
                }
            }
        }
        .overlay {
            if assets.isEmpty {
                ContentUnavailableView("相册是空的", systemImage: "photo.on.rectangle")
            }
        }
        .overlay(alignment: .top) { ToastOverlay() }
        .navigationTitle(album?.title ?? "相册")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) {
            if selecting { selectionBar }
        }
        .onAppear { reload() }
        .alert("重命名相册", isPresented: $showRename) {
            TextField("相册名字", text: $newName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                let name = newName
                Task { await model.renameAlbum(albumID, to: name) }
            }
        }
        .fullScreenCover(item: $reviewStart, onDismiss: { reload() }) { start in
            AlbumReviewView(albumID: albumID, assets: assets, startIndex: start.index)
                .environmentObject(model)
        }
        .sheet(isPresented: $showMovePicker) {
            AlbumPickerView(excluding: albumID) { target in
                let picked = selectedAssets
                Task {
                    if await model.move(picked, from: albumID, to: target.id) { finishSelection() }
                }
            }
            .environmentObject(model)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if showsCloseButton {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if selecting {
                Button("完成") {
                    selecting = false
                    selected = []
                }
            } else {
                Menu {
                    Button {
                        reviewStart = ReviewStart(index: 0)
                    } label: {
                        Label("逐张整理", systemImage: "rectangle.stack")
                    }
                    .disabled(assets.isEmpty)
                    Button {
                        selecting = true
                    } label: {
                        Label("选择照片", systemImage: "checkmark.circle")
                    }
                    .disabled(assets.isEmpty)
                    Button {
                        newName = album?.title ?? ""
                        showRename = true
                    } label: {
                        Label("重命名相册", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var selectionBar: some View {
        VStack(spacing: 6) {
            Text(selected.isEmpty ? "点照片来选择" : "已选 \(selected.count) 张")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    showMovePicker = true
                } label: {
                    Label("移到…", systemImage: "folder")
                }
                Spacer()
                Button {
                    let picked = selectedAssets
                    Task {
                        if await model.removeFromAlbum(picked, albumID: albumID) { finishSelection() }
                    }
                } label: {
                    Label("移出相册", systemImage: "rectangle.portrait.and.arrow.right")
                }
                Spacer()
                Button(role: .destructive) {
                    let picked = selectedAssets
                    Task {
                        if await model.deleteNow(picked, albumID: albumID) { finishSelection() }
                    }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func toggle(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func finishSelection() {
        selected = []
        selecting = false
        reload()
    }

    private func reload() {
        assets = model.fetchAssets(inAlbum: albumID)
        let ids = Set(assets.map(\.localIdentifier))
        selected = selected.filter { ids.contains($0) }
    }
}

// MARK: - One-by-one review of an album

/// Like the main sorter, but for photos already in an album:
/// tap another album = move there, "移出相册" = back to unsorted, swipe = previous / next.
struct AlbumReviewView: View {
    @EnvironmentObject var model: SorterModel
    @Environment(\.dismiss) private var dismiss
    let albumID: String
    @State private var assets: [PHAsset]
    @State private var index: Int
    @State private var drag: CGSize = .zero
    @State private var busy = false

    init(albumID: String, assets: [PHAsset], startIndex: Int) {
        self.albumID = albumID
        _assets = State(initialValue: assets)
        _index = State(initialValue: min(max(startIndex, 0), max(assets.count - 1, 0)))
    }

    private var current: PHAsset? { index < assets.count ? assets[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(model.album(albumID)?.title ?? "相册").font(.headline)
                    Text(assets.isEmpty ? "空" : "\(index + 1) / \(assets.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ZStack {
                if let asset = current {
                    AssetImageView(asset: asset)
                        .id(asset.localIdentifier)
                        .offset(x: drag.width)
                        .gesture(swipe)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("这个相册整理完了").font(.title3.bold())
                        Button("返回") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                Button {
                    step(-1)
                } label: {
                    Image(systemName: "chevron.left").frame(maxWidth: 44)
                }
                .disabled(index == 0)

                Button(role: .destructive) {
                    act { await model.deleteNow([$0], albumID: albumID) }
                } label: {
                    Label("删除", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .tint(.red)

                Button {
                    act { await model.removeFromAlbum([$0], albumID: albumID) }
                } label: {
                    Label("移出相册", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    step(1)
                } label: {
                    Image(systemName: "chevron.right").frame(maxWidth: 44)
                }
                .disabled(index >= assets.count - 1)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(current == nil || busy)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            Text("点下面的相册 = 把这张移过去")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            AlbumBar(excluding: albumID, enabled: current != nil && !busy, onTap: { target in
                act { await model.move([$0], from: albumID, to: target.id) }
            })
        }
        .overlay(alignment: .top) { ToastOverlay() }
    }

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { v in
                if v.translation.width < -80 { step(1) } else if v.translation.width > 80 { step(-1) }
                withAnimation(.spring(duration: 0.25)) { drag = .zero }
            }
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard next >= 0, next < assets.count else { return }
        index = next
    }

    /// Runs an action on the current photo; on success the photo leaves this album's list.
    private func act(_ op: @escaping (PHAsset) async -> Bool) {
        guard let asset = current, !busy else { return }
        busy = true
        Task {
            let ok = await op(asset)
            if ok, let i = assets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                assets.remove(at: i)
                if index >= assets.count { index = max(assets.count - 1, 0) }
            }
            busy = false
        }
    }
}

// MARK: - Album picker (for "移到…")

struct AlbumPickerView: View {
    @EnvironmentObject var model: SorterModel
    @Environment(\.dismiss) private var dismiss
    let excluding: String
    let onPick: (AlbumItem) -> Void

    var body: some View {
        NavigationStack {
            List(model.albumsByCount.filter { $0.id != excluding }) { album in
                Button {
                    onPick(album)
                    dismiss()
                } label: {
                    HStack {
                        Text(album.title).foregroundStyle(.primary)
                        Spacer()
                        Text("\(album.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("移到哪个相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
