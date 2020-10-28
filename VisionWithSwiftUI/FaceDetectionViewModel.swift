//
//  FaceDetectionViewModel.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import AVFoundation
import UIKit

final class FaceDetectionViewModel: NSObject, ObservableObject {
    @Published var image: UIImage?
    
    var previewLayer: CALayer!
    
    private let session = AVCaptureSession()
    
    override init() {
        super.init()
        
        startCaptureSession()
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
        
        session.startRunning()
    }
    
    private func getImageFromSampleBuffer(buffer: CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            let imageRect = CGRect(x: 0,
                                   y: 0,
                                   width: CVPixelBufferGetWidth(pixelBuffer),
                                   height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .up)
            }
        }
        
        return nil
    }
}

extension FaceDetectionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let image = getImageFromSampleBuffer(buffer: sampleBuffer) {
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
}
