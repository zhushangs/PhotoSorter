import Photos
import SwiftUI
import UIKit

// MARK: - Shared image manager (not actor-isolated so image loaders can use it)

enum PhotoAssets {
    static let manager = PHCachingImageManager()
    /// Pixel size used for the big preview. Big enough for a sharp full-width photo.
    static let previewSize = CGSize(width: 1600, height: 1600)

    static func previewOptions() -> PHImageRequestOptions {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true   // iCloud photos
        return opts
    }
}

// MARK: - Models

struct AlbumItem: Identifiable, Hashable {
    let id: String          // PHAssetCollection.localIdentifier
    var title: String
    var count: Int
}

private enum SortAction {
    case filed(albumID: String, index: Int)
    case skipped(index: Int)
    case markedDelete(assetID: String, index: Int)
}

private final class IDBox { var value: String? }

private struct LibrarySnapshot: @unchecked Sendable {
    var albums: [AlbumItem]
    var collections: [String: PHAssetCollection]
    var unsorted: [PHAsset]
}

// MARK: - Main model

@MainActor
final class SorterModel: ObservableObject {
    @Published private(set) var authStatus: PHAuthorizationStatus
    @Published private(set) var queue: [PHAsset] = []
    @Published private(set) var index = 0
    @Published private(set) var albums: [AlbumItem] = []
    @Published private(set) var barIDs: [String] = []
    @Published private(set) var pendingDelete: [String] = []
    @Published private(set) var isLoading = false
    @Published private var history: [SortAction] = []
    @Published var toast: String?
    @Published var newestFirst: Bool {
        didSet {
            defaults.set(newestFirst, forKey: Keys.newestFirst)
            Task { await reload() }
        }
    }

    private var collections: [String: PHAssetCollection] = [:]
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let bar = "barAlbumIDs"
        static let barInitialized = "barInitialized"
        static let pendingDelete = "pendingDelete"
        static let newestFirst = "newestFirst"
    }

    init() {
        let d = UserDefaults.standard
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        newestFirst = d.object(forKey: Keys.newestFirst) as? Bool ?? true
        barIDs = d.stringArray(forKey: Keys.bar) ?? []
        pendingDelete = d.stringArray(forKey: Keys.pendingDelete) ?? []
    }

    // MARK: Derived state

    var current: PHAsset? { index < queue.count ? queue[index] : nil }
    var remaining: Int { max(queue.count - index, 0) }
    var canUndo: Bool { !history.isEmpty }
    var barAlbums: [AlbumItem] {
        barIDs.compactMap { id in albums.first { $0.id == id } }
    }
    var otherAlbums: [AlbumItem] {
        albums.filter { !barIDs.contains($0.id) }
    }

    // MARK: Permission

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authStatus = status
        if status == .authorized { await reload() }
    }

    func refreshAuthStatus() {
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: Loading

    /// Reads all user albums, then collects every photo that isn't in any of them.
    func reload() async {
        guard authStatus == .authorized else { return }
        isLoading = true
        let pending = Set(pendingDelete)
        let newest = newestFirst
        let snap = await Task.detached(priority: .userInitiated) {
            SorterModel.scanLibrary(excluding: pending, newestFirst: newest)
        }.value

        collections = snap.collections
        albums = snap.albums
        queue = snap.unsorted
        index = 0
        history = []

        let valid = Set(snap.albums.map(\.id))
        if !defaults.bool(forKey: Keys.barInitialized) {
            // First launch: put every existing album on the bar.
            barIDs = snap.albums.map(\.id)
            defaults.set(true, forKey: Keys.barInitialized)
        } else {
            barIDs = barIDs.filter { valid.contains($0) }
        }
        saveBar()

        // Forget pending deletes for photos that no longer exist.
        let stillThere = PHAsset.fetchAssets(withLocalIdentifiers: pendingDelete, options: nil)
        var existing = Set<String>()
        stillThere.enumerateObjects { a, _, _ in existing.insert(a.localIdentifier) }
        pendingDelete = pendingDelete.filter { existing.contains($0) }
        savePending()

        isLoading = false
        prefetch()
    }

    nonisolated private static func scanLibrary(excluding pending: Set<String>, newestFirst: Bool) -> LibrarySnapshot {
        var albums: [AlbumItem] = []
        var colls: [String: PHAssetCollection] = [:]
        var filed = Set<String>()

        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        userAlbums.enumerateObjects { c, _, _ in
            guard c.canPerform(.addContent) else { return }
            let assets = PHAsset.fetchAssets(in: c, options: nil)
            assets.enumerateObjects { a, _, _ in filed.insert(a.localIdentifier) }
            albums.append(AlbumItem(id: c.localIdentifier, title: c.localizedTitle ?? "未命名", count: assets.count))
            colls[c.localIdentifier] = c
        }
        albums.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !newestFirst)]
        var unsorted: [PHAsset] = []
        PHAsset.fetchAssets(with: opts).enumerateObjects { a, _, _ in
            let id = a.localIdentifier
            if !filed.contains(id) && !pending.contains(id) { unsorted.append(a) }
        }
        return LibrarySnapshot(albums: albums, collections: colls, unsorted: unsorted)
    }

    private func prefetch() {
        let upcoming = Array(queue.dropFirst(index).prefix(4))
        guard !upcoming.isEmpty else { return }
        PhotoAssets.manager.startCachingImages(
            for: upcoming,
            targetSize: PhotoAssets.previewSize,
            contentMode: .aspectFit,
            options: PhotoAssets.previewOptions()
        )
    }

    private func advance() {
        index += 1
        prefetch()
    }

    // MARK: Sorting actions

    /// Put the current photo into an album and move to the next one.
    func file(into albumID: String) {
        guard let asset = current, let coll = collections[albumID] else { return }
        history.append(.filed(albumID: albumID, index: index))
        bumpCount(albumID, by: 1)
        let title = albums.first(where: { $0.id == albumID })?.title ?? ""
        toast = "→ \(title)"
        Haptics.tap()
        advance()

        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCollectionChangeRequest(for: coll)?.addAssets([asset] as NSArray)
                }
            } catch {
                self.toast = "放入相册失败：\(error.localizedDescription)"
            }
        }
    }

    func skip() {
        guard current != nil else { return }
        history.append(.skipped(index: index))
        advance()
    }

    /// Marks the current photo for deletion. Nothing is deleted until commitDeletes().
    func markDelete() {
        guard let asset = current else { return }
        history.append(.markedDelete(assetID: asset.localIdentifier, index: index))
        pendingDelete.append(asset.localIdentifier)
        savePending()
        Haptics.tap()
        advance()
    }

    func undo() {
        guard let last = history.popLast() else { return }
        switch last {
        case let .filed(albumID, idx):
            index = idx
            bumpCount(albumID, by: -1)
            if let coll = collections[albumID], idx < queue.count {
                let asset = queue[idx]
                Task {
                    try? await PHPhotoLibrary.shared().performChanges {
                        PHAssetCollectionChangeRequest(for: coll)?.removeAssets([asset] as NSArray)
                    }
                }
            }
        case let .skipped(idx):
            index = idx
        case let .markedDelete(assetID, idx):
            pendingDelete.removeAll { $0 == assetID }
            savePending()
            index = idx
        }
    }

    /// Deletes all marked photos at once (iOS shows one confirmation; photos go to "Recently Deleted").
    func commitDeletes() async {
        guard !pendingDelete.isEmpty else { return }
        let ids = pendingDelete
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            pendingDelete.removeAll { ids.contains($0) }
            savePending()
            history = []   // deleted photos can't be stepped back to
            toast = "已删除 \(ids.count) 张，可在“最近删除”里找回"
        } catch {
            // User tapped "Don't Allow" in the system dialog — keep them marked.
        }
    }

    /// Un-mark everything waiting for deletion and put those photos back in the queue.
    func clearPendingDeletes() async {
        pendingDelete = []
        savePending()
        await reload()
    }

    // MARK: Albums

    func createAlbum(named raw: String) async {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let box = IDBox()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                box.value = req.placeholderForCreatedAssetCollection.localIdentifier
            }
            guard let id = box.value,
                  let coll = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
            else { return }
            collections[id] = coll
            albums.append(AlbumItem(id: id, title: name, count: 0))
            albums.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            barIDs.append(id)
            saveBar()
        } catch {
            toast = "创建相册失败：\(error.localizedDescription)"
        }
    }

    /// Deletes the album itself. The photos stay in the library (and become "unsorted" again if
    /// they're in no other album).
    func deleteAlbum(_ id: String) async {
        guard let coll = collections[id] else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.deleteAssetCollections([coll] as NSArray)
            }
            await reload()
        } catch {
            // Cancelled in the system dialog.
        }
    }

    func addToBar(_ id: String) {
        guard !barIDs.contains(id) else { return }
        barIDs.append(id)
        saveBar()
    }

    func removeFromBar(_ id: String) {
        barIDs.removeAll { $0 == id }
        saveBar()
    }

    func moveBar(from source: IndexSet, to destination: Int) {
        barIDs.move(fromOffsets: source, toOffset: destination)
        saveBar()
    }

    // MARK: Helpers

    private func bumpCount(_ albumID: String, by delta: Int) {
        if let i = albums.firstIndex(where: { $0.id == albumID }) {
            albums[i].count = max(albums[i].count + delta, 0)
        }
    }

    private func saveBar() { defaults.set(barIDs, forKey: Keys.bar) }
    private func savePending() { defaults.set(pendingDelete, forKey: Keys.pendingDelete) }
}

@MainActor
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
