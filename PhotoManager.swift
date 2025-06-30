import Foundation
import Photos
import CoreLocation

class PhotoManager: ObservableObject {
    @Published var photosMetadata: [PhotoMetadata] = []

    func fetchPhotosMetadata(limit: Int, startDate: Date, endDate: Date, ascending: Bool, completion: @escaping () -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
                fetchOptions.fetchLimit = limit

                let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
                fetchOptions.predicate = predicate

                let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)

                var tempMetadata: [PhotoMetadata] = []
                let group = DispatchGroup()

                results.enumerateObjects { asset, _, _ in
                    group.enter()
                    self.getPhotoSize(asset: asset) { size in
                        let meta = PhotoMetadata(
                            creationDate: asset.creationDate,
                            fileSize: size,
                            location: asset.location?.coordinate
                        )
                        tempMetadata.append(meta)
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    DispatchQueue.main.async {
                        self.photosMetadata = tempMetadata
                        completion()
                    }
                }
            } else {
                print("❌ Permission Photos refusée")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    private func getPhotoSize(asset: PHAsset, completion: @escaping (Int) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first {
            if let fileSize = resource.value(forKey: "fileSize") as? Int {
                completion(fileSize)
                return
            }
        }
        completion(0)
    }
}
