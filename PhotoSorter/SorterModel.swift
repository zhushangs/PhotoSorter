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
    /// Newest photo in the album, shown as a little cover on the album bar.
    var cover: PHAsset? = nil
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
    /// true = album bar ordered by photo count (most first); false = the user's manual order.
    @Published var barSortByCount: Bool {
        didSet {
            defaults.set(barSortByCount, forKey: Keys.barSortByCount)
            resortBar()
        }
    }
    /// The order the bar is shown in. Only recomputed at calm moments (reload, closing a sheet…)
    /// so chips don't jump around while you're tapping them.
    @Published private(set) var barOrder: [String] = []
    /// Album writes still waiting to finish (shown as "保存中…").
    @Published private(set) var savingCount = 0
    /// A save that failed even after retrying. Shown until the user dismisses it.
    @Published var saveError: String?
    private var writeChain: Task<Void, Never>?

    private var collections: [String: PHAssetCollection] = [:]
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let bar = "barAlbumIDs"
        static let barInitialized = "barInitialized"
        static let pendingDelete = "pendingDelete"
        static let newestFirst = "newestFirst"
        static let barSortByCount = "barSortByCount"
    }

    init() {
        let d = UserDefaults.standard
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        newestFirst = d.object(forKey: Keys.newestFirst) as? Bool ?? true
        barSortByCount = d.object(forKey: Keys.barSortByCount) as? Bool ?? true
        barIDs = d.stringArray(forKey: Keys.bar) ?? []
        pendingDelete = d.stringArray(forKey: Keys.pendingDelete) ?? []
        barOrder = barIDs
    }

    // MARK: Derived state

    var current: PHAsset? { index < queue.count ? queue[index] : nil }
    var remaining: Int { max(queue.count - index, 0) }
    var canUndo: Bool { !history.isEmpty }
    var barAlbums: [AlbumItem] {
        barOrder.compactMap { id in albums.first { $0.id == id } }
    }
    var otherAlbums: [AlbumItem] {
        albums.filter { !barIDs.contains($0.id) }
    }
    var albumsByCount: [AlbumItem] {
        albums.sorted { $0.count != $1.count ? $0.count > $1.count : $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func album(_ id: String) -> AlbumItem? {
        albums.first { $0.id == id }
    }

    func resortBar() {
        guard barSortByCount else {
            barOrder = barIDs
            return
        }
        let byID = Dictionary(albums.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        barOrder = barIDs.sorted { a, b in
            let ca = byID[a]?.count ?? 0, cb = byID[b]?.count ?? 0
            if ca != cb { return ca > cb }
            return (byID[a]?.title ?? "").localizedStandardCompare(byID[b]?.title ?? "") == .orderedAscending
        }
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
        // Let queued album writes land first, otherwise just-sorted photos would look unsorted.
        await writeChain?.value
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
        resortBar()

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
            albums.append(AlbumItem(id: c.localIdentifier, title: c.localizedTitle ?? "未命名",
                                    count: assets.count, cover: assets.lastObject))
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
        if let i = albums.firstIndex(where: { $0.id == albumID }) { albums[i].cover = asset }
        let title = albums.first(where: { $0.id == albumID })?.title ?? ""
        toast = "→ \(title)"
        Haptics.tap()
        advance()

        enqueueWrite({
            PHAssetCollectionChangeRequest(for: coll)?.addAssets([asset] as NSArray)
        }, onFailure: { [weak self] error in
            guard let self else { return }
            self.refreshCounts([albumID])
            self.queue.append(asset)   // put it back so it gets sorted again
            self.saveError = "有一张照片没能放进「\(title)」，已经放回待整理的最后面。\n（\(error.localizedDescription)）"
        })
    }

    /// `expecting`: the photo the gesture started on. If the screen has already moved on
    /// (e.g. an album was tapped mid-animation), do nothing instead of hitting the next photo.
    func skip(expecting id: String? = nil) {
        guard let asset = current, id == nil || id == asset.localIdentifier else { return }
        history.append(.skipped(index: index))
        advance()
    }

    /// Marks the current photo for deletion. Nothing is deleted until commitDeletes().
    func markDelete(expecting id: String? = nil) {
        guard let asset = current, id == nil || id == asset.localIdentifier else { return }
        history.append(.markedDelete(assetID: asset.localIdentifier, index: index))
        pendingDelete.append(asset.localIdentifier)
        savePending()
        Haptics.tap()
        toast = "已标记删除 · 长按垃圾桶可全部删除"
        advance()
    }

    /// Deletes the current photo right away. iOS asks for confirmation itself; the photo goes to
    /// "Recently Deleted" (recoverable for 30 days). Cancelling the iOS dialog changes nothing.
    func deleteCurrent() async {
        guard let asset = current else { return }
        let id = asset.localIdentifier
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
        } catch {
            return
        }
        if let i = queue.firstIndex(where: { $0.localIdentifier == id }) {
            queue.remove(at: i)
            // Steps recorded at or after this position no longer line up with the queue.
            history.removeAll { Self.position(of: $0) >= i }
            if index > i { index -= 1 }
        }
        Haptics.tap()
        toast = "已删除，可在“最近删除”找回"
        prefetch()
    }

    private static func position(of action: SortAction) -> Int {
        switch action {
        case let .filed(_, idx): return idx
        case let .skipped(idx): return idx
        case let .markedDelete(_, idx): return idx
        }
    }

    func undo() {
        guard let last = history.popLast() else { return }
        switch last {
        case let .filed(albumID, idx):
            index = idx
            bumpCount(albumID, by: -1)
            if let coll = collections[albumID], idx < queue.count {
                let asset = queue[idx]
                // Queued after the original "add", so it can never run before it.
                enqueueWrite({
                    PHAssetCollectionChangeRequest(for: coll)?.removeAssets([asset] as NSArray)
                }, onSuccess: { [weak self] in
                    self?.refreshCounts([albumID])
                }, onFailure: { [weak self] _ in
                    self?.saveError = "撤销时没能把照片从相册里拿出来，可以到相册里手动移出。"
                })
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
            resortBar()
        } catch {
            toast = "创建相册失败：\(error.localizedDescription)"
        }
    }

    func renameAlbum(_ id: String, to raw: String) async {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let coll = collections[id] else { return }
        guard coll.canPerform(.rename) else {
            toast = "这个相册不能改名"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest(for: coll)?.title = name
            }
            if let fresh = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject {
                collections[id] = fresh
            }
            if let i = albums.firstIndex(where: { $0.id == id }) {
                albums[i].title = name
            }
            albums.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            resortBar()
            toast = "已改名为“\(name)”"
        } catch {
            toast = "改名失败：\(error.localizedDescription)"
        }
    }

    // MARK: Photos inside an album

    func fetchAssets(inAlbum id: String) -> [PHAsset] {
        guard let coll = collections[id] else { return [] }
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        var list: [PHAsset] = []
        PHAsset.fetchAssets(in: coll, options: opts).enumerateObjects { a, _, _ in list.append(a) }
        return list
    }

    /// Moves photos from one album to another (removed from the source, added to the target).
    func move(_ assets: [PHAsset], from sourceID: String, to targetID: String) async -> Bool {
        guard !assets.isEmpty, sourceID != targetID,
              let src = collections[sourceID], let dst = collections[targetID] else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest(for: dst)?.addAssets(assets as NSArray)
                PHAssetCollectionChangeRequest(for: src)?.removeAssets(assets as NSArray)
            }
            refreshCounts([sourceID, targetID])
            Haptics.tap()
            toast = assets.count == 1 ? "→ \(album(targetID)?.title ?? "")" : "\(assets.count) 张 → \(album(targetID)?.title ?? "")"
            return true
        } catch {
            toast = "移动失败：\(error.localizedDescription)"
            return false
        }
    }

    /// Takes photos out of an album. Ones that end up in no album go back to the unsorted queue.
    func removeFromAlbum(_ assets: [PHAsset], albumID: String) async -> Bool {
        guard !assets.isEmpty, let coll = collections[albumID] else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest(for: coll)?.removeAssets(assets as NSArray)
            }
            refreshCounts([albumID])
            let known = Set(queue.map(\.localIdentifier))
            let backToUnsorted = assets.filter {
                $0.mediaType == .image && !known.contains($0.localIdentifier) && isInNoAlbum($0)
            }
            queue.append(contentsOf: backToUnsorted)
            Haptics.tap()
            toast = "已移出相册"
            return true
        } catch {
            toast = "移出失败：\(error.localizedDescription)"
            return false
        }
    }

    /// Deletes right away (iOS asks for confirmation). Photos go to "Recently Deleted".
    func deleteNow(_ assets: [PHAsset], albumID: String?) async -> Bool {
        guard !assets.isEmpty else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            if let albumID { refreshCounts([albumID]) }
            toast = "已删除 \(assets.count) 张"
            return true
        } catch {
            return false   // cancelled
        }
    }

    private func isInNoAlbum(_ asset: PHAsset) -> Bool {
        var found = false
        PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
            .enumerateObjects { c, _, stop in
                if c.assetCollectionSubtype == .albumRegular {
                    found = true
                    stop.pointee = true
                }
            }
        return !found
    }

    private func refreshCounts(_ ids: [String]) {
        for id in ids {
            guard let coll = collections[id], let i = albums.firstIndex(where: { $0.id == id }) else { continue }
            let result = PHAsset.fetchAssets(in: coll, options: nil)
            albums[i].count = result.count
            albums[i].cover = result.lastObject
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
        resortBar()
    }

    func removeFromBar(_ id: String) {
        barIDs.removeAll { $0 == id }
        saveBar()
        resortBar()
    }

    /// Manual reordering; only used when the bar isn't sorted by count.
    func moveBar(from source: IndexSet, to destination: Int) {
        guard !barSortByCount else { return }
        barIDs.move(fromOffsets: source, toOffset: destination)
        saveBar()
        resortBar()
    }

    // MARK: Helpers

    /// Runs photo-library writes strictly one at a time, in the order they were requested,
    /// retrying up to 3 times. Fast tapping no longer fires overlapping requests.
    private func enqueueWrite(_ change: @escaping () -> Void,
                              onSuccess: (() -> Void)? = nil,
                              onFailure: @escaping (Error) -> Void) {
        let previous = writeChain
        savingCount += 1
        writeChain = Task {
            await previous?.value
            var lastError: Error?
            for attempt in 1...3 {
                do {
                    try await PHPhotoLibrary.shared().performChanges(change)
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    if attempt < 3 {
                        try? await Task.sleep(for: .milliseconds(400 * attempt))
                    }
                }
            }
            if let lastError { onFailure(lastError) } else { onSuccess?() }
            savingCount -= 1
        }
    }

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
