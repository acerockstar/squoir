//
//  CameraPreviewView.swift
//  Squoir
//
//  Created by Hao Dong on 18/10/2016.
//  Copyright © 2016 Arlix Technologies. All rights reserved.
//

import UIKit
import AVFoundation

class CameraPreviewView: UIView {
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get {
            return cameraPreviewLayer.session
        }
        set {
            cameraPreviewLayer.session = newValue
        }
    }
    
    override static var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

