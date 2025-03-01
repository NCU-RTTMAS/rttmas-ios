//
//  CGImage.swift
//  YOLO
//
//  Created by Quisette Chung on 2025/2/25.
//  Copyright © 2025 Ultralytics. All rights reserved.
//
import CoreImage

extension CGImage {
    static func create(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
