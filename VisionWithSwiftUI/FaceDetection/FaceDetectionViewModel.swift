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
    var previewLayer = AVCaptureVideoPreviewLayer()

    @Published var faceRoll: Double = 0.0
    @Published var faceYaw: Double = 0.0
    @Published var captureQuality: Float = 0.0

    private let session = AVCaptureSession()
    private var captureDeviceResolution = CGSize()

    var detectionOverlayLayer: CALayer?
    var detectedFaceRectangleShapeLayer: CAShapeLayer?

    override init() {
        super.init()

        configureCamera()
        setupVisionDrawingLayers()
    }

    private func configureCamera() {
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return
        }

        let captureDeviceInput = try! AVCaptureDeviceInput(device: device)
        if session.canAddInput(captureDeviceInput) {
            session.addInput(captureDeviceInput)
        }

        if let highestResolution = highestResolution420Format(for: device) {
            captureDeviceResolution = highestResolution.resolution
        }

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        session.commitConfiguration()

        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer = previewLayer
        previewLayer.videoGravity = .resizeAspectFill
    }

    private func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format?
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)

        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format

            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }

        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }

        return nil
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

    private func performVisionRequests(on pixelBuffer: CVPixelBuffer) {
        var requestOptions = [VNImageOption: Any]()
        if let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: requestOptions)
        let faceDetectionRequest = VNDetectFaceCaptureQualityRequest()
        do {
            try handler.perform([faceDetectionRequest])
            guard let faceObservations = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            DispatchQueue.main.async {
                self.drawFaceObservations(faceObservations)
                self.updateFaceOrientationInfo(faceObservations)
                self.updateCaptureQualityInfo(faceObservations)
            }
        } catch {
            print("Vision error: \(error.localizedDescription)")
        }
    }

    private func setupVisionDrawingLayers() {
        let captureDeviceResolution = self.captureDeviceResolution

        let captureDeviceBounds = CGRect(x: 0,
                                         y: 0,
                                         width: captureDeviceResolution.width,
                                         height: captureDeviceResolution.height)

        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
                                                     y: captureDeviceBounds.midY)

        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)

        let overlayLayer = CALayer()
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)

        let faceRectangleShapeLayer = CAShapeLayer()
        faceRectangleShapeLayer.bounds = captureDeviceBounds
        faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
        faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
        faceRectangleShapeLayer.fillColor = nil
        faceRectangleShapeLayer.strokeColor = UIColor.green.cgColor
        faceRectangleShapeLayer.lineWidth = 5

        overlayLayer.addSublayer(faceRectangleShapeLayer)
        previewLayer.addSublayer(overlayLayer)

        detectionOverlayLayer = overlayLayer
        detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
    }

    private func updateLayerGeometry() {
        guard let overlayLayer = detectionOverlayLayer else {
            return
        }

        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)

        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))

        let scaleX = videoPreviewRect.width / captureDeviceResolution.width
        let scaleY = videoPreviewRect.height / captureDeviceResolution.height

        let affineTransform = CGAffineTransform(scaleX: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)

        let previewLayerBounds = previewLayer.bounds
        overlayLayer.position = CGPoint(x: previewLayerBounds.midX, y: previewLayerBounds.midY)
    }

    private func addIndicator(to faceRectanglePath: CGMutablePath, for faceObservation: VNFaceObservation) {
        let displaySize = captureDeviceResolution

        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
        faceRectanglePath.addRect(faceBounds)
    }

    private func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        guard let faceRectangleShapeLayer = detectedFaceRectangleShapeLayer else {
            return
        }

        CATransaction.begin()

        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)

        let faceRectanglepath = CGMutablePath()

        for faceObservation in faceObservations {
            addIndicator(to: faceRectanglepath, for: faceObservation)
        }

        faceRectangleShapeLayer.path = faceRectanglepath

        updateLayerGeometry()

        CATransaction.commit()
    }

    private func updateFaceOrientationInfo(_ faceObservations: [VNFaceObservation]) {
        for faceObservation in faceObservations {
            if let roll = faceObservation.roll, let yaw = faceObservation.yaw {
                faceRoll = roll.doubleValue * 180.0 / Double.pi
                faceYaw = yaw.doubleValue * 180.0 / Double.pi
            }
        }
    }

    private func updateCaptureQualityInfo(_ faceObservations: [VNFaceObservation]) {
        for faceObservation in faceObservations {
            if let quality = faceObservation.faceCaptureQuality {
                captureQuality = quality
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FaceDetectionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        performVisionRequests(on: pixelBuffer)
    }
}
