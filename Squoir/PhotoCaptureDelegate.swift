//
//  PhotoCaptureDelegate.swift
//  Squoir
//
//  Created by Hao Dong on 18/10/2016.
//  Copyright © 2016 Arlix Technologies. All rights reserved.
//

import AVFoundation
import Photos

class PhotoCaptureDelegate: NSObject {
    let requestedPhotoSettings: AVCapturePhotoSettings
    var photoCaptureBegins: (() -> ())? = .none
    var photoCaptured: (() -> ())? = .none
    fileprivate let completionHandler: (PhotoCaptureDelegate, PHAsset?) -> ()
    
    fileprivate var photoData: Data? = .none
    
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         completionHandler: @escaping (PhotoCaptureDelegate, PHAsset?) -> ()) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.completionHandler = completionHandler
    }
    
    fileprivate func cleanup(asset: PHAsset? = .none) {
        completionHandler(self, asset)
    }
}

extension PhotoCaptureDelegate: AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        photoCaptureBegins?()
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        photoCaptured?()
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let photoSampleBuffer = photoSampleBuffer {
            photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
        } else {
            print("Error capturing photo: \(error)")
            return
        }
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("error capturing photo: \(error)")
            cleanup()
            return
        }
        
        guard let photoData = photoData else {
            print("no photo data available")
            cleanup()
            return
        }
        
        saveToPhotoLibrary(data: photoData) { [unowned self] (asset) in
            self.cleanup(asset: asset)
        }
    }
}




private func saveToPhotoLibrary(data: Data, completion: @escaping (PHAsset?) -> ()) {
    var assetIdentifier: String?
    PHPhotoLibrary.requestAuthorization { (status) in
        if status == .authorized {
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let placeholder = creationRequest.placeholderForCreatedAsset
                
                creationRequest.addResource(with: .photo, data: data, options: .none)
                
                assetIdentifier = placeholder?.localIdentifier
                
                }, completionHandler: { (success, error) in
                    if let error = error {
                        print("There was an error saving to the photo library: \(error)")
                    }
                    var asset: PHAsset? = .none
                    if let assetIdentifier = assetIdentifier {
                        asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: .none).firstObject
                    }
                    completion(asset)
            })
        } else {
            print("Need authorisation to write to the photo library")
            completion(.none)
        }
    }
}

