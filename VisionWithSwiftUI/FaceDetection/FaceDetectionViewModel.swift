//
//  FaceDetectionViewModel.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import AVFoundation
import UIKit
import Vision

final class FaceDetectionViewModel: NSObject, ObservableObject {
    var previewLayer: CALayer!
    @Published var faceRoll: Double = 0.0
    @Published var faceYaw: Double = 0.0
    
    private let session = AVCaptureSession()
    
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequstHandler = VNSequenceRequestHandler()
    
    override init() {
        super.init()
        
        startCaptureSession()
        prepareVisionRequest()
    }
    
    private func startCaptureSession() {
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
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
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { (request, error) in
            if error != nil {
                print("FaceDetection error: \(String(describing: error))")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        }
        
        detectionRequests = [faceDetectionRequest]
        sequenceRequstHandler = VNSequenceRequestHandler()
    }
    
    private func updateFaceOrientationInfo(_ faceObservations: [VNFaceObservation]) {
        for faceObservation in faceObservations {
            if let roll = faceObservation.roll, let yaw = faceObservation.yaw {
                faceRoll = roll.doubleValue * 180.0 / Double.pi
                faceYaw = yaw.doubleValue * 180.0 / Double.pi
            }
        }
    }
}

extension FaceDetectionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame")
            return
        }
        
        let exifOrientation = exifOrientationForDeviceOrientation(UIDevice.current.orientation)
        
        guard let requests = trackingRequests, !requests.isEmpty else {
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = detectionRequests else {
                    return
                }
                
                try imageRequestHandler.perform(detectRequests)
            } catch  let error as NSError {
                NSLog("Failedto perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        do {
            try sequenceRequstHandler.perform(requests, on: pixelBuffer, orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                
                newTrackingRequests.append(trackingRequest)
            }
        }
        
        trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            return
        }
        
        var faceRectangleRequests = [VNDetectFaceRectanglesRequest]()
        
        for _ in newTrackingRequests {
            let faceRectanglesRequest = VNDetectFaceRectanglesRequest { (request, error) in
                if error != nil {
                    print("FaceRectangles error: \(String(describing: error))")
                }
                
                guard let rectanglesRequest = request as? VNDetectFaceRectanglesRequest,
                      let results = rectanglesRequest.results as? [VNFaceObservation] else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.updateFaceOrientationInfo(results)
                }
            }
            
            faceRectangleRequests.append(faceRectanglesRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceRectangleRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
        }
    }
    
    private func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
        case .landscapeLeft:
            return .downMirrored
        case .landscapeRight:
            return .upMirrored
        default:
            return .leftMirrored
        }
    }
}
