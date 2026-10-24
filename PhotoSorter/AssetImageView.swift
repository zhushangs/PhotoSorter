import Photos
import SwiftUI
import UIKit

final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var requestID: PHImageRequestID = PHInvalidImageRequestID

    func load(_ asset: PHAsset) {
        cancel()
        requestID = PhotoAssets.manager.requestImage(
            for: asset,
            targetSize: PhotoAssets.previewSize,
            contentMode: .aspectFit,
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
