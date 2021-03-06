//
//  ViewController.swift
//  AV Foundation
//
//  Created by Pranjal Satija on 5/22/17.
//  Copyright © 2017 Pranjal Satija. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {
    
    var level: Float = 0.0
    let cameraController = CameraController()
    
    @IBAction func focus(_ sender: UIButton) {
        do {
            try cameraController.setFocus()
        } catch {
            print("failed setFocus\n")
        }
    }
    @IBOutlet fileprivate var captureButton: UIButton!
    
    @IBOutlet var delay: UITextField!
    
    @IBOutlet var numPhotos: UITextField!
    ///Displays a preview of the video output generated by the device's cameras.
    @IBOutlet fileprivate var capturePreviewView: UIView!

    
    
    override var prefersStatusBarHidden: Bool { return true }
    
}

extension ViewController {
    override func viewDidLoad() {
        self.level = 1.0
        func configureCameraController() {
            cameraController.prepare {(error) in
                if let error = error {
                    print(error)
                }
                try? self.cameraController.displayPreview(on: self.capturePreviewView)
            }
        }
        
        func styleCaptureButton() {
            captureButton.layer.borderColor = UIColor.black.cgColor
            captureButton.layer.borderWidth = 2
            
            captureButton.layer.cornerRadius = min(captureButton.frame.width, captureButton.frame.height) / 2
        }
        
        styleCaptureButton()
        configureCameraController()
        capturePreviewView.sendSubview(toBack: capturePreviewView)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
}


func toggleFlash() {
    if let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo), device.hasTorch {
        do {
            try device.lockForConfiguration()
            if(device.isTorchActive) {
                device.torchMode = .off
                print("off")
            } else {
                try device.setTorchModeOnWithLevel(0.00001)
                print("on")
            }
            device.unlockForConfiguration()
        } catch {
            print("error")
        }
    }
}

extension ViewController {
    @IBAction func captureImage(_ sender: UIButton) {
            self.cameraController.captureImage {(image, error) in
                guard let image = image else {
                    print(error ?? "Image capture error")
                    return
                }
                try? PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        usleep(500000)
        toggleFlash()
        usleep(500000)
        cameraController.captureImage {(image, error) in
            guard let image = image else {
                print(error ?? "Image capture error")
                return
            }
            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } 
    }
}

