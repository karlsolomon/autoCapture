//
//  CameraController.swift
//  AV Foundation
//
//  Created by Pranjal Satija on 29/5/2017.
//  Copyright © 2017 AppCoda. All rights reserved.
//

import AVFoundation
import UIKit

class CameraController: NSObject {
    var exposureTime = AVCaptureExposureDurationCurrent
    var lensPosition : Float = 1.00 //.05 = 3mm
    
    var captureSession: AVCaptureSession?
    
    var currentCameraPosition: CameraPosition?
    
    var photoOutput: AVCapturePhotoOutput?
    
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var flashMode = AVCaptureFlashMode.off
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
}

extension CameraController {
    
    func setFocus() throws {
        let session = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified)
        guard let cameras = (session?.devices.flatMap { $0 }), !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
        
        for camera in cameras {
            if camera.position == .back {
                self.rearCamera = camera
                
                try camera.lockForConfiguration()
                //if(camera.isExposureModeSupported(AVCaptureExposureMode.custom)) {
                //    camera.setExposureModeCustomWithDuration(duration: CMTime, iso: Float, completionHandler: ((CMTime) -> Void)!)
                //}
                //camera.autoFocusRangeRestriction = .near

                //camera.focusMode = .autoFocus
                camera.setFocusModeLockedWithLensPosition(self.lensPosition, completionHandler: { (CMTime) in
                    camera.exposureMode = .autoExpose
                    print("\n\nLensPosition: \(camera.lensPosition)\nExposureTime: \(camera.exposureDuration)\nCurrentISO: \(camera.iso)")
                    camera.unlockForConfiguration()
                })
            }
        }
    }
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        func configureCaptureDevices() throws {
            let session = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified)
            guard let cameras = (session?.devices.flatMap { $0 }), !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
            
            for camera in cameras {
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    //if(camera.isExposureModeSupported(AVCaptureExposureMode.custom)) {
                    //    camera.setExposureModeCustomWithDuration(duration: CMTime, iso: Float, completionHandler: ((CMTime) -> Void)!)
                    //}
                    camera.exposureMode = .autoExpose
                    camera.focusMode = .autoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
            else { throw CameraControllerError.noCamerasAvailable }
        }
        
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.photoOutput) { captureSession.addOutput(self.photoOutput) }
            captureSession.startRunning()
        }
        

        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                return
            }
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
}



extension CameraController: AVCapturePhotoCaptureDelegate {
    public func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?,
                        resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
        //else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.dngPhotoDataRepresentation(forRawSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
        else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
            let image = UIImage(data: data) {
                var info = mach_timebase_info()
                guard mach_timebase_info(&info) == KERN_SUCCESS else {
                    self.photoCaptureCompletionBlock?(nil, nil)
                    return
                }
                print(mach_absolute_time() * UInt64(info.numer) / UInt64(info.denom))
                //toggleFlash()
                self.photoCaptureCompletionBlock?(image, nil)
            }
            
        else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }
}

extension CameraController {
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case rear
    }
}
