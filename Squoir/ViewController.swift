//
//  ViewController.swift
//  Squoir
//
//  Created by Alex Choi on 12/10/2016.
//  Copyright © 2016 Arlix Technologies. All rights reserved.
//

import UIKit

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {
    
    // MARK: Interface Builder
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var cameraPreviewView: CameraPreviewView!
    
    @IBAction func handleShutterButtonTapped(_ sender: UIButton) {
        capturePhoto()
    }
    
    // MARK: Stored properties
    fileprivate let session = AVCaptureSession()
    fileprivate let sessionQueue = DispatchQueue(label: "com.razeware.PhotoMe.session-queue")
    var videoDeviceInput: AVCaptureDeviceInput!
    fileprivate let photoOutput = AVCapturePhotoOutput()
    fileprivate var photoCaptureDelegates = [Int64 : PhotoCaptureDelegate]()
    fileprivate var lastPhoto: PHAsset? = .none
    
    
    // MARK: UIViewController Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable UI until session up and running
        shutterButton.isEnabled = false
        
        // Prepare the session
        cameraPreviewView.session = session
        
        // Request authorisation
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { [unowned self] success in
            if !success {
                print("Error: Squoir requires access to the camera and the microphone")
                return
            }
            self.sessionQueue.resume()
        }
        
        // Configure and start the capture session
        sessionQueue.async { [unowned self] in
            self.prepareCaptureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addObserver()
        sessionQueue.async {
            self.session.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            self.session.stopRunning()
        }
        removeObserver()
        super.viewWillDisappear(true)
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

extension ViewController {
    fileprivate func prepareCaptureSession() {
        session.beginConfiguration()
        
        session.sessionPreset = AVCaptureSessionPresetPhoto
        
        // Create a video input device - using the front-facing camera
        do {
            let videoDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front)
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    self.cameraPreviewView.cameraPreviewLayer.connection.videoOrientation = .portrait
                }
            } else {
                print("Couldn't add device to the session")
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            return
        }
        
        // Create audio input
        do {
            let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Couldn't add audio device to the session")
                return
            }
        } catch {
            print("Unable to create audio device input: \(error)")
            return
        }
        
        // Create photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
        } else {
            print("Unable to add photo output")
            return
        }
        
        session.commitConfiguration()
    }
}


extension ViewController {
    // Capturing photos
    fileprivate func capturePhoto() {
        let cameraPreviewLayerOrientation = cameraPreviewView.cameraPreviewLayer.connection.videoOrientation
        
        sessionQueue.async {
            if let photoOutputConnection = self.photoOutput.connection(withMediaType: AVMediaTypeVideo) {
                photoOutputConnection.videoOrientation = cameraPreviewLayerOrientation
            }
            
            // Capture a JPEG
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = .off
            photoSettings.isHighResolutionPhotoEnabled = true
            
            // Create a delegate
            let photoCaptureDelegate = PhotoCaptureDelegate(with: photoSettings) { [unowned self] (photoCaptureDelegate, asset) in
                self.sessionQueue.async { [unowned self] in
                    self.photoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = .none
                    self.lastPhoto = asset
                }
            }
            
            // UI Update for begins
            photoCaptureDelegate.photoCaptureBegins = { [unowned self] in
                DispatchQueue.main.async {
                    self.shutterButton.isEnabled = false
                    self.cameraPreviewView.cameraPreviewLayer.opacity = 0
                    UIView.animate(withDuration: 0.2) {
                        self.cameraPreviewView.cameraPreviewLayer.opacity = 1
                    }
                }
            }
            
            // Handle completion
            photoCaptureDelegate.photoCaptured = { [unowned self] in
                DispatchQueue.main.async {
                    self.shutterButton.isEnabled = true
                }
            }
            
            self.photoCaptureDelegates[photoCaptureDelegate.requestedPhotoSettings.uniqueID] = photoCaptureDelegate
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate)
        }
    }
}



extension ViewController {
    fileprivate func addObserver() {
        session.addObserver(self, forKeyPath: #keyPath(AVCaptureSession.running), options: .new, context: .none)
    }
    
    fileprivate func removeObserver() {
        session.removeObserver(self, forKeyPath: #keyPath(AVCaptureSession.running))
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVCaptureSession.running) {
            DispatchQueue.main.async { [unowned self] in
                self.shutterButton.isEnabled = self.session.isRunning
            }
        }
    }
}
