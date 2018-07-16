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
    
    lazy var vision = Vision.vision()

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // カメラの設定
        setupCamera()
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
        output.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        output.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        captureSession.commitConfiguration()
       
        let queue = DispatchQueue(label: "output.queue")
        output.setSampleBufferDelegate(self, queue: queue)
        
        // セッションからプレビューを表示
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        self.previewView.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        
        //leftMirrored for front camera
        let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.leftMirrored.rawValue))
        
        //detectFace(on: ciImageWithOrientation)
    }
    
}
