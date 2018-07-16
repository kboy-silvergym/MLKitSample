//
//  ViewController.swift
//  MLKitSample
//
//  Created by Kei Fujikawa on 2018/07/16.
//  Copyright © 2018年 Kboy. All rights reserved.
//

import AVFoundation
import UIKit
import Firebase

class ViewController: UIViewController {
    @IBOutlet weak var previewView: UIView!
    
    var input: AVCaptureDeviceInput!
    var captureSession: AVCaptureSession!
    
    var camera: AVCaptureDevice!
    
    // Face
    let shapeLayer = CAShapeLayer()
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    private lazy var vision = Vision.vision()
    
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // カメラの設定
        setupCamera()
        setUpAnnotationOverlayView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        shapeLayer.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        view.layer.addSublayer(shapeLayer)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // camera stop メモリ解放
        captureSession.stopRunning()
        
        for output in captureSession.outputs {
            //session.removeOutput((output as? AVCaptureOutput)!)
            captureSession.removeOutput(output)
        }
        
        for input in captureSession.inputs {
            //session.removeInput((input as? AVCaptureInput)!)
            captureSession.removeInput(input)
        }
        captureSession = nil
        camera = nil
    }
    
    private func setUpAnnotationOverlayView() {
        previewView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: previewView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            ])
    }
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func setupCamera(){
        captureSession = AVCaptureSession()
        
        // 背面・前面カメラの選択
        camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front)
        
        // インプット
        do {
            input = try AVCaptureDeviceInput(device: camera)
            
        } catch let error as NSError {
            print(error)
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        // アウトプット
        let output = AVCaptureVideoDataOutput()
        output.videoSettings =
            [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        captureSession.commitConfiguration()
       
        let queue = DispatchQueue(label: "output.queue")
        output.setSampleBufferDelegate(self, queue: queue)
        
        // セッションからプレビューを表示
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    // MARK: On-Device Detection
    
    private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        let options = VisionFaceDetectorOptions()
        options.landmarkType = .all
        options.isTrackingEnabled = true
        let faceDetector = vision.faceDetector(options: options)
        faceDetector.detect(in: image) { features, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard error == nil, let features = features, !features.isEmpty else {
                self.removeDetectionAnnotations()
                print("On-Device face detector returned no results.")
                return
            }
            self.removeDetectionAnnotations()
            for face in features {
                let normalizedRect = CGRect(
                    x: face.frame.origin.x / width,
                    y: face.frame.origin.y / height,
                    width: face.frame.size.width / width,
                    height: face.frame.size.height / height
                )
                let standardizedRect =
                    self.previewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect).standardized
                UIUtilities.addRectangle(
                    standardizedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.green
                )
                //self.addLandmarks(forFace: face, transform: self.transformMatrix(face.frame.size))
            }
        }
    }
    
    private func transformMatrix(_ faceSize: CGSize) -> CGAffineTransform {
        let imageViewWidth = previewView.frame.size.width
        let imageViewHeight = previewView.frame.size.height
        let imageWidth = previewLayer.frame.size.width
        let imageHeight = previewLayer.frame.size.height
        
        let imageViewAspectRatio = imageViewWidth / imageViewHeight
        let imageAspectRatio = imageWidth / imageHeight
        let scale = (imageViewAspectRatio > imageAspectRatio) ?
            imageViewHeight / imageHeight :
            imageViewWidth / imageWidth
        
        // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
        // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
        let scaledImageWidth = imageWidth * scale
        let scaledImageHeight = imageHeight * scale
        let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
        let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)
        
        var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }
    
    private func addLandmarks(forFace face: VisionFace, transform: CGAffineTransform) {
        // Mouth
        if let bottomMouthLandmark = face.landmark(ofType: .mouthBottom) {
            let landmarkPoint = landmarkPointFrom(bottomMouthLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.smallDotRadius
            )
        }
        if let leftMouthLandmark = face.landmark(ofType: .mouthLeft) {
            let landmarkPoint = landmarkPointFrom(leftMouthLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.smallDotRadius
            )
        }
        if let rightMouthLandmark = face.landmark(ofType: .mouthRight) {
            let landmarkPoint = landmarkPointFrom(rightMouthLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.smallDotRadius
            )
        }
        
        // Nose
        if let noseBaseLandmark = face.landmark(ofType: .noseBase) {
            let landmarkPoint = landmarkPointFrom(noseBaseLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.yellow,
                radius: Constants.smallDotRadius
            )
        }
        
        // Eyes
        if let leftEyeLandmark = face.landmark(ofType: .leftEye) {
            let landmarkPoint = landmarkPointFrom(leftEyeLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Constants.largeDotRadius
            )
        }
        if let rightEyeLandmark = face.landmark(ofType: .rightEye) {
            let landmarkPoint = landmarkPointFrom(rightEyeLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Constants.largeDotRadius
            )
        }
        
        // Ears
        if let leftEarLandmark = face.landmark(ofType: .leftEar) {
            let landmarkPoint = landmarkPointFrom(leftEarLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Constants.largeDotRadius
            )
        }
        if let rightEarLandmark = face.landmark(ofType: .rightEar) {
            let landmarkPoint = landmarkPointFrom(rightEarLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Constants.largeDotRadius
            )
        }
        
        // Cheeks
        if let leftCheekLandmark = face.landmark(ofType: .leftCheek) {
            let landmarkPoint = landmarkPointFrom(leftCheekLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Constants.largeDotRadius
            )
        }
        if let rightCheekLandmark = face.landmark(ofType: .rightCheek) {
            let landmarkPoint = landmarkPointFrom(rightCheekLandmark.position)
            let transformedPoint = landmarkPoint.applying(transform)
            UIUtilities.addCircle(
                atPoint: landmarkPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Constants.largeDotRadius
            )
        }
    }
    
    private func landmarkPointFrom(_ visionPoint: VisionPoint) -> CGPoint {
        return CGPoint(x: CGFloat(visionPoint.x.floatValue), y: CGFloat(visionPoint.y.floatValue))
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        let visionImage = VisionImage(buffer: sampleBuffer)
        let metadata = VisionImageMetadata()
        let visionOrientation = UIUtilities.visionImageOrientation(from: UIUtilities.imageOrientation(fromDevicePosition: .front))
        metadata.orientation = visionOrientation
        visionImage.metadata = metadata
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
    }
}
