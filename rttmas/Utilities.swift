//
//  Utilities.swift
//  YOLO
//
//  Created by Quisette Chung on 2025/2/27.
//  Copyright © 2025 Ultralytics. All rights reserved.
//

import UIKit
import Vision

class Utilities {
    static func saveText(text: String, file: String = "saved.txt") {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(file)
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(text.data(using: .utf8)!)
                fileHandle.closeFile()
            } catch {
                do {
                    try text.write(to: fileURL, atomically: false, encoding: .utf8)
                } catch {
                    print("Utilities: No file written")
                }
            }
        }
    }
    
    static func saveImage() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileURL = dir!.appendingPathComponent("saved.jpg")
        let image = UIImage(named: "ultralytics_yolo_logotype.png")
        FileManager.default.createFile(atPath: fileURL.path, contents: image!.jpegData(compressionQuality: 0.5), attributes: nil)
    }
    
    static func freeSpace() -> Double {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return Double(values.volumeAvailableCapacityForImportantUsage!) / 1E9
        } catch {
            print("Utilities: Error retrieving storage capacity: \(error.localizedDescription)")
            return 0
        }
    }
    
    static func memoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / 1E9
        } else {
            return 0
        }
    }
    
    static func recognizeText(from image: UIImage) -> String {
        guard let cgImage = image.cgImage else {
            print("Utilities: Failed to get CGImage for OCR")
            return ""
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try requestHandler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("Utilities: No OCR observations found")
                return ""
            }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            let result = recognizedStrings.joined(separator: " ")
            print("Utilities: Recognized text: '\(result)'")
            return result
        } catch {
            print("Utilities: OCR error: \(error)")
            return ""
        }
    }
}
