import Photos
import SwiftUI
import UIKit

final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var requestID: PHImageRequestID = PHInvalidImageRequestID

    func load(_ asset: PHAsset,
              targetSize: CGSize = PhotoAssets.previewSize,
              contentMode: PHImageContentMode = .aspectFit) {
        cancel()
        requestID = PhotoAssets.manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: PhotoAssets.previewOptions()
        ) { [weak self] img, _ in
            guard let img else { return }
            DispatchQueue.main.async { self?.image = img }
        }
    }

    func cancel() {
        if requestID != PHInvalidImageRequestID {
            PhotoAssets.manager.cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }
}

/// Big, aspect-fit preview used while sorting.
struct AssetImageView: View {
    let asset: PHAsset
    @StateObject private var loader = AssetImageLoader()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .bottom) {
            if let date = asset.creationDate {
                Text(date, format: .dateTime.year().month().day())
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
        .onAppear { loader.load(asset) }
        .onDisappear { loader.cancel() }
    }
}

/// Square, aspect-fill thumbnail for album grids.
struct ThumbnailView: View {
    let asset: PHAsset
    @StateObject private var loader = AssetImageLoader()

    var body: some View {
        Color.secondary.opacity(0.12)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if asset.mediaType == .video {
                    Image(systemName: "video.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(5)
                }
            }
            .onAppear {
                loader.load(asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill)
            }
            .onDisappear { loader.cancel() }
    }
}

/// Short message that slides in from the top (e.g. "→ 旅行").
struct ToastOverlay: View {
    @EnvironmentObject var model: SorterModel

    var body: some View {
        if let toast = model.toast {
            Text(toast)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast) {
                    try? await Task.sleep(for: .seconds(1.2))
                    withAnimation { model.toast = nil }
                }
        }
    }
}
