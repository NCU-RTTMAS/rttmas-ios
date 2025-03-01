import CoreMedia
import UIKit
import Vision

class DetectionManager {
    weak var viewController: ViewController?
    private var lastDetectionTime: Date = .distantPast  // Tracks the last detection timestamp
    
    init(viewController: ViewController) {
        self.viewController = viewController
    }
    
    func predict(sampleBuffer: CMSampleBuffer) {
        // Check if 3 seconds have passed since the last detection
        let currentTime = Date()
        let timeSinceLastDetection = currentTime.timeIntervalSince(lastDetectionTime)
        guard timeSinceLastDetection >= 1 else {
//            print("DetectionManager: Skipping detection - \(timeSinceLastDetection) seconds since last detection")
            viewController?.currentBuffer = nil  // Clear buffer to avoid reprocessing
            return
        }
        
        guard let viewController = viewController,
              viewController.currentBuffer == nil,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("DetectionManager: Predict skipped - buffer or viewController unavailable")
            return
        }
        
        viewController.currentBuffer = pixelBuffer
        if !viewController.frameSizeCaptured {
            let frameWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let frameHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
            viewController.longSide = max(frameWidth, frameHeight)
            viewController.shortSide = min(frameWidth, frameHeight)
            viewController.frameSizeCaptured = true
            print("DetectionManager: Frame size set - \(frameWidth)x\(frameHeight)")
        }
        
        let imageOrientation: CGImagePropertyOrientation
        switch UIDevice.current.orientation {
        case .portrait: imageOrientation = .up
        case .portraitUpsideDown: imageOrientation = .down
        case .landscapeLeft, .landscapeRight: imageOrientation = .up
        case .unknown: imageOrientation = .up
        default: imageOrientation = .up
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation)
        if UIDevice.current.orientation != .faceUp {
            viewController.t0 = CACurrentMediaTime()
            do {
                print("DetectionManager: Starting car detection at \(currentTime)")
                try handler.perform([viewController.visionRequest])
                lastDetectionTime = currentTime  // Update the last detection time
            } catch {
                print("DetectionManager: Car prediction error: \(error)")
            }
            viewController.t1 = CACurrentMediaTime() - viewController.t0
            print("DetectionManager: Car detection took \(viewController.t1) seconds")
        } else {
            print("DetectionManager: Skipped detection due to face-up orientation")
        }
        viewController.currentBuffer = nil
        
        // Schedule next prediction check
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.predictNextFrameIfNeeded(sampleBuffer: sampleBuffer)
        }
    }
    
    private func predictNextFrameIfNeeded(sampleBuffer: CMSampleBuffer) {
        guard let viewController = viewController,
              viewController.videoCaptureManager.isRunning else {
            print("DetectionManager: Prediction loop stopped - video not running")
            return
        }
        // Instead of immediately predicting, wait until the next frame and check the time
        print("DetectionManager: Checking next frame for detection")
        self.predict(sampleBuffer: sampleBuffer)
    }
    
    func processCarObservations(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let viewController = self.viewController,
                  let results = request.results as? [VNRecognizedObjectObservation] else {
                print("DetectionManager: No car detection results")
                self.viewController!.show(predictions: [], frame: self.viewController!.latestFrame)
                return
            }
            let carPredictions = results.filter { ["car", "truck", "motorcycle", "bus"].contains($0.labels[0].identifier.lowercased()) && $0.confidence > 0.8 }
            viewController.lastCarPredictions = carPredictions
            print("DetectionManager: Detected \(carPredictions.count) cars")
            self.processCars(predictions: carPredictions)
        }
    }
    
    func processCars(predictions: [VNRecognizedObjectObservation]) {
        guard let viewController = viewController,
              let frame = viewController.latestFrame else {
            print("DetectionManager: No frame available for processing cars")
            return
        }
        
        var allPredictions: [VNRecognizedObjectObservation] = predictions
        
        for car in predictions {
            if let croppedCar = viewController.cropImage(frame, bbox: car.boundingBox){
                viewController.latestCroppedCarImage = croppedCar
                print("DetectionManager: Cropped car image for bounding box: \(car.boundingBox)")
                DispatchQueue.global(qos: .userInitiated).async {
                    self.processPlateForCar(croppedCar: croppedCar, carPrediction: car)
                }
            } else {
                print("DetectionManager: Failed to crop car image for bounding box: \(car.boundingBox)")
            }
        }
        viewController.show(predictions: allPredictions, frame: frame)
        viewController.updateCroppedImagesTab()
        print("DetectionManager: Updated UI with \(allPredictions.count) predictions")
    }
    func convertCreateMLToYOLO(boundingBox: CGRect) -> CGRect {
        // Create ML: y is bottom edge (bottom-left origin)
        // YOLO: y should be top edge (top-left origin)
        let yoloY = 1.0 - boundingBox.origin.y - boundingBox.height
        return CGRect(
            x: boundingBox.origin.x,
            y: yoloY,
            width: boundingBox.width,
            height: boundingBox.height
        )
    }
    
    private func processPlateForCar(croppedCar: UIImage, carPrediction: VNRecognizedObjectObservation) {
            guard let viewController = viewController else {
                print("DetectionManager: ViewController unavailable for plate processing")
                return
            }
            
            let ciImage = CIImage(image: croppedCar)!
            let handler = VNImageRequestHandler(ciImage: ciImage)
            do {
                print("DetectionManager: Starting plate detection for car")
                try handler.perform([viewController.licensePlateRequest])
            } catch {
                print("DetectionManager: License plate detection error: \(error)")
                return
            }
            
            guard let plateImage = viewController.latestCroppedPlateImage else {
                print("DetectionManager: No plate image detected for car with bounding box: \(carPrediction.boundingBox), skipped")
                DispatchQueue.main.async {
                    viewController.show(predictions: viewController.lastCarPredictions, frame: viewController.latestFrame!)
                    viewController.updateCroppedImagesTab()
                }
                return
            }
            
            // Scale the plate bounding box (from processLicensePlateObservations)
            let plateObservation = (viewController.licensePlateRequest.results as? [VNRecognizedObjectObservation])?.first(where: { $0.labels[0].identifier.lowercased() == "license_plate" && $0.confidence > 0.6 })
            guard let plateBoundingBox = plateObservation?.boundingBox else {
                print("DetectionManager: No plate bounding box available")
                DispatchQueue.main.async {
                    ViewController.croppedHistory.insert((carImage: croppedCar, plateImage: plateImage), at: 0)
                    let combinedPredictions = viewController.lastCarPredictions + [carPrediction]
                    viewController.show(predictions: combinedPredictions, frame: viewController.latestFrame!)
                    viewController.updateCroppedImagesTab()
                }
                return
            }
            
            let scaledPlateBox = scaleBoundingBox(plateBoundingBox, scaleFactor: 1.1)
            
            // Draw the scaled bounding box on the car image
            let carImageWithBoundingBox = drawBoundingBox(on: croppedCar, boundingBox: scaledPlateBox)
            
            DispatchQueue.main.async {
                // Insert the modified car image (with bounding box) into croppedHistory
                ViewController.croppedHistory.insert((carImage: carImageWithBoundingBox, plateImage: plateImage), at: 0)
//                print("DetectionManager: Added to croppedHistory with bounding box drawn: \(ViewController.croppedHistory.count) entries")
                let combinedPredictions = viewController.lastCarPredictions + [carPrediction]
                viewController.show(predictions: combinedPredictions, frame: viewController.latestFrame!)
                viewController.updateCroppedImagesTab()
            }
        }
    
    func processLicensePlateObservations(for request: VNRequest, error: Error?) {
        guard let viewController = viewController,
              let results = request.results as? [VNRecognizedObjectObservation],
              let plate = results.first(where: { $0.labels[0].identifier.lowercased() == "license_plate" && $0.confidence > 0.8 }),
              let carImage = viewController.latestCroppedCarImage else {
            print("DetectionManager: No plate detection results or car image")
            return
        }
        let scaledBoundingBox = scaleBoundingBox(plate.boundingBox, scaleFactor: 1.1)
        
        if let croppedPlate = viewController.cropImage(carImage, bbox: convertCreateMLToYOLO(boundingBox:scaledBoundingBox )) {
            viewController.latestCroppedPlateImage = croppedPlate
            let width = croppedPlate.size.width
            let height = croppedPlate.size.height
            print("DetectionManager: Cropped plate dimensions: \(width)x\(height)")
            
            if width <= 2 || height <= 2 {
                print("DetectionManager: Skipping OCR: Image too small (\(width)x\(height))")
                DispatchQueue.main.async {
                    viewController.ocrResults[plate.uuid.uuidString] = "Too small"
                    let combinedPredictions = viewController.lastCarPredictions + [plate]
                    viewController.show(predictions: combinedPredictions, frame: viewController.latestFrame!)
                    viewController.updateCroppedImagesTab()
                }
                return
            }
            
            let ocrText = Utilities.recognizeText(from: croppedPlate)
            DispatchQueue.main.async {
                viewController.ocrResults[plate.uuid.uuidString] = ocrText
                let combinedPredictions = viewController.lastCarPredictions + [plate]
                viewController.show(predictions: combinedPredictions, frame: viewController.latestFrame!)
                viewController.updateCroppedImagesTab()
            }
        } else {
            print("DetectionManager: Failed to crop license plate image with bounding box: \(plate.boundingBox)")
        }
    }
    
    /// Draws a bounding box on an image.
        /// - Parameters:
        ///   - image: The original image to draw on.
        ///   - boundingBox: The normalized bounding box to draw (in [0, 1] coordinates).
        /// - Returns: A new UIImage with the bounding box drawn.
        private func drawBoundingBox(on image: UIImage, boundingBox: CGRect) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(at: .zero)
            
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                return image
            }
            
            // Convert normalized bounding box to pixel coordinates
            let imageWidth = image.size.width
            let imageHeight = image.size.height
            let rect = CGRect(
                x: boundingBox.origin.x * imageWidth,
                y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight, // Flip y-axis for UIKit
                width: boundingBox.width * imageWidth,
                height: boundingBox.height * imageHeight
            )
            
            // Draw the bounding box
            context.setStrokeColor(UIColor.systemYellow.cgColor) // Customize color as needed
            context.setLineWidth(5.0) // Customize thickness as needed
            context.stroke(rect)
            
            let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
            return resultImage
        }
    private func scaleBoundingBox(_ boundingBox: CGRect, scaleFactor: CGFloat) -> CGRect {
            var scaledBox = boundingBox
            
            // Calculate new width and height
            let newWidth = scaledBox.width * scaleFactor
            let newHeight = scaledBox.height * scaleFactor
            
            // Adjust origin to keep the box centered
            scaledBox.origin.x -= (newWidth - scaledBox.width) / 2
            scaledBox.origin.y -= (newHeight - scaledBox.height) / 2
            
            // Update the size
            scaledBox.size = CGSize(width: newWidth, height: newHeight)
            
            // Ensure the scaled box stays within [0, 1] normalized coordinates
            return scaledBox.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
}
