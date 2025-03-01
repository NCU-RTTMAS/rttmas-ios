import Foundation
import UIKit

/// Manages the visualization of bounding boxes and associated labels for object detection results.
class BoundingBoxView {
    /// The layer that draws the bounding box around a detected object.
    let shapeLayer: CAShapeLayer
    
    /// The layer that displays the label and confidence score for the detected object.
    let textLayer: CATextLayer
    
    /// Timer to control visibility duration
    private var hideTimer: Timer?
    
    /// Initializes a new BoundingBoxView with configured shape and text layers.
    init() {
        shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 4
        shapeLayer.isHidden = true
        
        textLayer = CATextLayer()
        textLayer.isHidden = true
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.fontSize = 14
        textLayer.font = UIFont(name: "Avenir", size: textLayer.fontSize)
        textLayer.alignmentMode = .center
    }
    
    /// Adds the bounding box and text layers to a specified parent layer.
    /// - Parameter parent: The CALayer to which the bounding box and text layers will be added.
    func addToLayer(_ parent: CALayer) {
        parent.addSublayer(shapeLayer)
        parent.addSublayer(textLayer)
        print("BoundingBoxView: Added to layer \(parent)")
    }
    
    /// Updates the bounding box and label to be visible for 3 seconds with specified properties.
    /// - Parameters:
    ///   - frame: The CGRect frame defining the bounding box's size and position.
    ///   - label: The text label to display (e.g., object class and confidence).
    ///   - color: The color of the bounding box stroke and label background.
    ///   - alpha: The opacity level for the bounding box stroke and label background.
    func show(frame: CGRect, label: String, color: UIColor, alpha: CGFloat) {
        print("BoundingBoxView: Showing frame \(frame), label \(label), color \(color), alpha \(alpha)")
        CATransaction.setDisableActions(true)
        
        let path = UIBezierPath(roundedRect: frame, cornerRadius: 6.0)
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color.withAlphaComponent(alpha).cgColor
        shapeLayer.isHidden = false
        
        textLayer.string = label
        textLayer.backgroundColor = color.withAlphaComponent(alpha).cgColor
        textLayer.isHidden = false
        textLayer.foregroundColor = UIColor.white.withAlphaComponent(alpha).cgColor
        
        let attributes = [NSAttributedString.Key.font: textLayer.font as Any]
        let textRect = label.boundingRect(
            with: CGSize(width: 400, height: 100),
            options: .truncatesLastVisibleLine,
            attributes: attributes, context: nil)
        let textSize = CGSize(width: textRect.width + 12, height: textRect.height)
        let textOrigin = CGPoint(x: frame.origin.x - 2, y: frame.origin.y - textSize.height - 2)
        textLayer.frame = CGRect(origin: textOrigin, size: textSize)
        
        // Validate frame bounds
        if frame.width <= 0 || frame.height <= 0 || frame.origin.x < 0 || frame.origin.y < 0 {
            print("BoundingBoxView: Warning - Invalid frame dimensions or position: \(frame)")
        }
        
        // Cancel any existing hide timer
//        hideTimer?.invalidate()
//        
//        // Schedule hide after 3 seconds
//        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
//            self.hide()
//        }
    }
    
    /// Hides the bounding box and text layers, but only if called explicitly outside the timer.
    func hide() {
        shapeLayer.isHidden = true
        textLayer.isHidden = true
        hideTimer?.invalidate()
        hideTimer = nil
        print("BoundingBoxView: Hidden")
    }
}
