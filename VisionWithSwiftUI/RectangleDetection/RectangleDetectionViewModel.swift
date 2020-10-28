//
//  RectangleDetectionViewModel.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import AVFoundation
import UIKit
import Vision

final class RectangleDetectionViewModel: NSObject, ObservableObject {
    var previewLayer: CALayer!
    
    private let session = AVCaptureSession()
    
    private var detectionRequests: [VNDetectRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequstHandler = VNSequenceRequestHandler()
    
    override init() {
        super.init()
        
        startCaptureSession()
        prepareVisionRequest()
    }
    
    private func startCaptureSession() {
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }
        
        let captureDeviceInput = try! AVCaptureDeviceInput(device: device)
        if session.canAddInput(captureDeviceInput) {
            session.addInput(captureDeviceInput)
        }
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        session.commitConfiguration()
        
        let videoDataOutputQueue = DispatchQueue(label: "dev.ynskski.VisionWithSwiftUI")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer = previewLayer
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    func startSession() {
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    private func prepareVisionRequest() {
        var requests = [VNTrackObjectRequest]()
        
        let rectangleDetectionRequest = VNDetectRectanglesRequest { request, error in
            if error != nil {
                print("RectangleRequest error: \(String(describing: error))")
            }
            
            guard let rectangleRequest = request as? VNDetectRectanglesRequest,
                  let results = rectangleRequest.results as? [VNFaceObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                for observation in results {
                    let rectangleTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(rectangleTrackingRequest)
                }
                self.trackingRequests = requests
            }
        }
        
        detectionRequests = [rectangleDetectionRequest]
        sequenceRequstHandler = VNSequenceRequestHandler()
    }
}

extension RectangleDetectionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    
}
