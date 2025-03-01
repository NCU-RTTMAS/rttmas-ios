//
//  ModelManager.swift
//  YOLO
//
//  Created by Quisette Chung on 2025/2/27.
//  Copyright © 2025 Ultralytics. All rights reserved.
//
import CoreML
import Vision

class ModelManager {
    weak var viewController: ViewController?
    
    var mlModel: MLModel
    var licensePlateModel: MLModel
    
    var detector: VNCoreMLModel
    var licensePlateDetector: VNCoreMLModel
    
    let visionRequest: VNCoreMLRequest
    let licensePlateRequest: VNCoreMLRequest
    
    init(viewController: ViewController) {
        self.viewController = viewController
        let config = MLModelConfiguration()
        if #available(iOS 17.0, *) {
            config.setValue(1, forKey: "experimentalMLE5EngineUsage")
        }
        
        do {
            mlModel = try yolo11m(configuration: config).model
            licensePlateModel = try Car_Plate_Detector(configuration: config).model
            detector = try VNCoreMLModel(for: mlModel)
            licensePlateDetector = try VNCoreMLModel(for: licensePlateModel)
        } catch {
            fatalError("Failed to load models: \(error.localizedDescription)")
        }
        
        visionRequest = VNCoreMLRequest(model: detector) { [weak viewController] request, error in
            viewController?.detectionManager.processCarObservations(for: request, error: error)
        }
        visionRequest.imageCropAndScaleOption = .scaleFill
        
        licensePlateRequest = VNCoreMLRequest(model: licensePlateDetector) { [weak viewController] request, error in
            viewController?.detectionManager.processLicensePlateObservations(for: request, error: error)
        }
        licensePlateRequest.imageCropAndScaleOption = .scaleFill
        
        setModel()
    }
    
    func setModel() {
        do {
            detector = try VNCoreMLModel(for: mlModel)
            detector.featureProvider = ThresholdProvider()
            licensePlateDetector = try VNCoreMLModel(for: licensePlateModel)
            licensePlateDetector.featureProvider = ThresholdProvider()
            print("ModelManager: Models configured successfully")
        } catch {
            print("ModelManager: Failed to configure models: \(error.localizedDescription)")
        }
    }
    
    func updateModel(index: Int) {
        switch index {
        case 0:
            mlModel = try! yolo11n(configuration: MLModelConfiguration()).model
        case 1:
            mlModel = try! yolo11s(configuration: MLModelConfiguration()).model
        case 2:
            mlModel = try! yolo11m(configuration: MLModelConfiguration()).model
        case 3:
            mlModel = try! yolo11l(configuration: MLModelConfiguration()).model
        case 4:
            mlModel = try! yolo11x(configuration: MLModelConfiguration()).model
        default:
            break
        }
        setModel()
    }
}
