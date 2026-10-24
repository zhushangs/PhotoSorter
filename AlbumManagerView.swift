import SwiftUI

struct AlbumManagerView: View {
    @EnvironmentObject var model: SorterModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var albumToDelete: AlbumItem?

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("新建相册") {
                    HStack {
                        TextField("相册名字", text: $newName)
                            .onSubmit(create)
                        Button("创建", action: create)
                            .disabled(trimmedName.isEmpty)
                    }
                }

                Section {
                    ForEach(model.barAlbums) { album in
                        row(album)
                            .swipeActions {
                                Button("移出") { model.removeFromBar(album.id) }
                                    .tint(.orange)
                                Button("删除相册", role: .destructive) { albumToDelete = album }
                            }
                    }
                    .onMove { model.moveBar(from: $0, to: $1) }
                } header: {
                    Text("相册栏（点右上角“编辑”排序）")
                } footer: {
                    Text("左滑：“移出”只是不在相册栏显示，“删除相册”会删掉相册本身（照片不会被删）。")
                }

                if !model.otherAlbums.isEmpty {
                    Section("其他相册（点 + 加到相册栏）") {
                        ForEach(model.otherAlbums) { album in
                            HStack {
                                row(album)
                                Button {
                                    model.addToBar(album.id)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.borderless)
                            }
                            .swipeActions {
                                Button("删除相册", role: .destructive) { albumToDelete = album }
                            }
                        }
                    }
                }
            }
            .navigationTitle("管理相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .confirmationDialog(
                "删除相册“\(albumToDelete?.title ?? "")”？",
                isPresented: Binding(
                    get: { albumToDelete != nil },
                    set: { if !$0 { albumToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除相册", role: .destructive) {
                    if let album = albumToDelete {
                        Task { await model.deleteAlbum(album.id) }
                    }
                    albumToDelete = nil
                }
                Button("取消", role: .cancel) { albumToDelete = nil }
            } message: {
                Text("只删除相册，里面的照片会留在图库里，并重新变成“未分类”。")
            }
        }
    }

    private func row(_ album: AlbumItem) -> some View {
        HStack {
            Text(album.title)
            Spacer()
            Text("\(album.count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func create() {
        let name = trimmedName
        guard !name.isEmpty else { return }
        newName = ""
        Task { await model.createAlbum(named: name) }
    }
}
