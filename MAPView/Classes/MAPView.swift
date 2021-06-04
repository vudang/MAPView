//
//  MAPView.swift
//  MAPView
//
//  Created by Petr Bobák on 29/11/2018.
//  Copyright © 2018 Oneprove. All rights reserved.
//

import UIKit
import CameraCapture
import AVFoundation

private class PrivateProtocol : NSObject, UIScrollViewDelegate {
    private weak var parent: MAPView?
    
    init(parent: MAPView) {
        super.init()
        self.parent = parent
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return parent?.contextView
    }
}

public typealias FingerprintPreprocessingOperation = (UIImage) -> UIImage

public class MAPView: UIView {
    // MARK: Private Vars
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contextView: UIView!
    @IBOutlet weak var overviewImageView: UIImageView!
    @IBOutlet weak var cameraPreview: CameraPreview!
    
    private var subdelegate: PrivateProtocol?
    
    // Marging of fingerprintRect from edge of contentView (display edge)
    private static let defaultFingerprintRectMarginFactor: CGFloat = 0.85
    private static let defaultMaxCameraPreviewAlpha: CGFloat = 0.8
    private static let defaultMinCameraPreviewAlpha: CGFloat = 0.5
    
    private var fingerprintRectMarginFactor = MAPView.defaultFingerprintRectMarginFactor
    
    // Debug stuff
    private let debug = false
    
    // MARK: Public Vars
    
    /// The minimum cameraPreview's alpha value. Recall: the value of this property is a floating-point number in the range 0.0 to 1.0, where 0.0 represents totally transparent and 1.0 represents totally opaque.
    public var minCameraPreviewAlpha = MAPView.defaultMinCameraPreviewAlpha
    
    /// The maximum cameraPreview's alpha value. Recall: the value of this property is a floating-point number in the range 0.0 to 1.0, where 0.0 represents totally transparent and 1.0 represents totally opaque.
    public var maxCameraPreviewAlpha = MAPView.defaultMaxCameraPreviewAlpha
    
    /// A delegate object to receive messages about capture progress and results.
    public weak var delegate: CameraCaptureDelegate? {
        didSet {
            cameraPreview.delegate = delegate
        }
    }
    
    /// Indicates whether the receiver is running.
    public var isRunning: Bool {
        return cameraPreview.cameraCapture.isRunning
    }
    
    // MARK: Public Methods
    
    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    /// Returns an object initialized from data in a given unarchiver.
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    /// Changes a zoom of underlying overview image.
    public func changeZoom(value: CGFloat) {
        let currentZoomScale = value * (scrollView.maximumZoomScale - scrollView.minimumZoomScale) + scrollView.minimumZoomScale
        scrollView.setZoomScale(currentZoomScale, animated: false)
        
        let width = frame.size.width
        let height = frame.size.height
        
        let contentOffsetX = -((width / 2.0) - cameraPreview.center.x * scrollView.maximumZoomScale) * value
        let contentOffsetY = -((height / 2.0) - cameraPreview.center.y * scrollView.maximumZoomScale) * value
        let contentOffset = CGPoint(x: contentOffsetX, y: contentOffsetY)
        
        scrollView.setContentOffset(contentOffset, animated: false)
        
        cameraPreview.alpha = (1 - value) * (maxCameraPreviewAlpha - minCameraPreviewAlpha) + minCameraPreviewAlpha
    }
    
    /**
     Initializes the MAPView with overview image and fingerprint rectangle.
     
     - parameters:
        - overviewImage: The overview image of the artwork.
        - fingerprintRect: Fingerprint rectangle in coordinate system of overview image.
        - completion: The completion block called after execution.
     */
    public func locateFingerprint(overviewImage: UIImage, fingerprintRect: CGRect, completion: (() -> Void)? = nil) {
        if overviewImage.size == .zero || fingerprintRect.isEmpty {
            fatalError("Overview image or fingerprint is empty")
        }
        
        
        // Calculate context size
        let contextSize = CGSize(width: max(overviewImage.size.width, fingerprintRect.size.width),
                                 height: max(overviewImage.size.height, fingerprintRect.size.height))
        
        // Fit context into contextView
        let contextWithinContextView = AVMakeRect(aspectRatio: contextSize, insideRect: contextView.bounds)
        
        // Retrieve scale
        let scale = contextWithinContextView.size.width / contextSize.width
        
        // Scale overview and fingerprint
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledFingerprintRect = fingerprintRect.applying(scaleTransform)
        let scaledOverviewImageSize = overviewImage.size.applying(scaleTransform)
        
        DispatchQueue.main.async {
            // Calculate origin of overviewImageView within context fitted into contextView (i.e., contextSizeFittedInContentView)
            self.overviewImageView.frame = CGRect(origin:
                                                    CGPoint(
                                                        x: contextWithinContextView.origin.x + (contextWithinContextView.size.width - scaledOverviewImageSize.width) / 2,
                                                        y: contextWithinContextView.origin.y + (contextWithinContextView.size.height - scaledOverviewImageSize.height) / 2
                                                    ), size: scaledOverviewImageSize)
            
            // Derive origin of cameraPreview within context fitted into contextView
            self.cameraPreview.frame = CGRect(origin:
                                                CGPoint(
                                                    x: self.overviewImageView.frame.origin.x + scaledFingerprintRect.origin.x,
                                                    y: self.overviewImageView.frame.origin.y + scaledFingerprintRect.origin.y
                                                ), size: scaledFingerprintRect.size)
            
            // Set overview image
            self.overviewImageView.image = overviewImage
            
            // Calculate maxScale of fingerprint that fits into contextView
            let maxScale = min(self.contextView.frame.size.width / min(self.cameraPreview.frame.size.width, self.overviewImageView.frame.size.width),
                               self.contentView.frame.size.height / min(self.cameraPreview.frame.size.height, self.overviewImageView.frame.size.height))
            
            self.scrollView.minimumZoomScale = 1
            self.scrollView.maximumZoomScale = self.fingerprintRectMarginFactor * maxScale
            self.cameraPreview.alpha = self.maxCameraPreviewAlpha
            
            completion?()
        }
    }
    
    /// Initiates a photo capture.
    public func captureFingerprintPhoto() {
        cameraPreview.capturePhoto()
    }
    
    /// Start the camera session.
    public func start() {
        cameraPreview.activateSession()
    }
    
    /// Stop the camera session.
    public func stop() {
        cameraPreview.deactivateSession()
    }
    
    // MARK: Private Methods
    private func commonInit() {
        let bundle = Bundle(for: self.classForCoder)
        let className = String(describing: MAPView.self)
        bundle.loadNibNamed(className, owner: self, options: nil)
        addSubview(contentView)
        sendSubviewToBack(contentView)
        contentView.frame = self.bounds
        
        subdelegate = PrivateProtocol(parent: self)
        scrollView.delegate = subdelegate
        
        if debug {
            contextView.backgroundColor = .orange
            cameraPreview.backgroundColor = UIColor.green.withAlphaComponent(0.5)
        }
    }
    
    private func drawRectangle(rect: CGRect) {
        let layer = CAShapeLayer()
        layer.path = UIBezierPath.init(rect: rect).cgPath
        layer.fillColor = UIColor.red.withAlphaComponent(0.45).cgColor
        overviewImageView.layer.addSublayer(layer)
    }
}

// MARK: Torch extension
extension MAPView {
    /// A Boolean value that specifies whether the capture device has a torch.
    public var hasTorch: Bool {
        return cameraPreview.cameraCapture.hasTorch
    }
    
    /// A Boolean value indicating whether the device’s torch is currently active.
    public var isTorchActive: Bool {
        return cameraPreview.cameraCapture.isTorchActive
    }
    
    /// The current torch mode.
    public var torchMode: AVCaptureDevice.TorchMode {
        get {
            return cameraPreview.cameraCapture.torchMode
        }
        set {
            cameraPreview.cameraCapture.torchMode = newValue
        }
    }
    
    /// The current torch brightness level.
    public var torchLevel: Float {
        return cameraPreview.cameraCapture.torchLevel
    }
    
    /// Sets the illumination level when in torch mode.
    public func setTorchModeOn(level: Float) {
        cameraPreview.cameraCapture.setTorchModeOn(level: level)
    }
    
    // A Boolean value that specifies whether the capture device has a torch.
    public func toggleTorch(level: Float = AVCaptureDevice.maxAvailableTorchLevel) -> Bool {
        cameraPreview.cameraCapture.toggleTorch(level: level)
    }
}
