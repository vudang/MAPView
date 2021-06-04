//
//  CameraPreview.swift
//  MAPView
//
//  Created by Petr Bobák on 06/12/2018.
//  Copyright © 2018 Oneprove. All rights reserved.
//

import UIKit
import AVFoundation
import ImageIO
import os.log
import CameraCapture

class CameraPreview: UIView {
    public var cameraCapture: CameraCapture!
    
    
    // MARK: Public Vars
    public weak var delegate: CameraCaptureDelegate? {
        didSet {
            cameraCapture.delegate = delegate
        }
    }
    
    // MARK: Lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        initCameraCapture { _ in
            self.layer.addSublayer(self.cameraCapture.previewLayer!)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initCameraCapture { _ in
            self.layer.addSublayer(self.cameraCapture.previewLayer!)
        }
    }
    
    deinit {
        deactivateSession()
    }
    
    private func initCameraCapture(completion: @escaping (Bool) -> Void) {
        cameraCapture = CameraCapture()
        
        cameraCapture.configure { success in
            if success {
                // Once everything is set up, we can start capturing live video.
                self.cameraCapture.start()
            } else {
                print("Could not set up camera")
            }
            completion(success)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        cameraCapture.previewLayer?.bounds = bounds
        cameraCapture.previewLayer?.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }
    
    // MARK: Public Methods
    func capturePhoto() {
        cameraCapture.capturePhoto()
    }
    
    func activateSession() {
        #if IOS_SIMULATOR
        return
        #else
        cameraCapture.start()
        #endif
    }
    
    func isSessionRunning() -> Bool {
        return cameraCapture.isRunning
    }
    
    func deactivateSession() {
        if cameraCapture.isRunning {
            cameraCapture.stop()
        }
    }
}
