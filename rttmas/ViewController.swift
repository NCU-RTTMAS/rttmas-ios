import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController, VideoCaptureDelegate, AVCapturePhotoCaptureDelegate {
    var ocrResults: [String: String] = [:]
    @IBOutlet var videoPreview: UIView!
    @IBOutlet var View0: UIView!
    @IBOutlet var segmentedControl: UISegmentedControl!
    @IBOutlet var playButtonOutlet: UIBarButtonItem!
    @IBOutlet var pauseButtonOutlet: UIBarButtonItem!
    @IBOutlet var slider: UISlider!
    @IBOutlet var sliderConf: UISlider!
    @IBOutlet weak var sliderConfLandScape: UISlider!
    @IBOutlet var sliderIoU: UISlider!
    @IBOutlet weak var sliderIoULandScape: UISlider!
    @IBOutlet weak var labelName: UILabel!
    @IBOutlet weak var labelFPS: UILabel!
    @IBOutlet weak var labelZoom: UILabel!
    @IBOutlet weak var labelVersion: UILabel!
    @IBOutlet weak var labelSlider: UILabel!
    @IBOutlet weak var labelSliderConf: UILabel!
    @IBOutlet weak var labelSliderConfLandScape: UILabel!
    @IBOutlet weak var labelSliderIoU: UILabel!
    @IBOutlet weak var labelSliderIoULandScape: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var focus: UIImageView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var hoveringTabButton: UIButton!
    static var croppedHistory: [(carImage: UIImage, plateImage: UIImage)] = []
    
    let selection = UISelectionFeedbackGenerator()
    lazy var modelManager = ModelManager(viewController: self)
    lazy var videoCaptureManager = VideoCaptureManager(viewController: self)
    lazy var detectionManager = DetectionManager(viewController: self)
    
    lazy var visionRequest = modelManager.visionRequest
    lazy var licensePlateRequest = modelManager.licensePlateRequest
    
    var currentBuffer: CVPixelBuffer?
    var framesDone = 0
    var t0 = 0.0
    var t1 = 0.0
    var t2 = 0.0
    var t3 = CACurrentMediaTime()
    var t4 = 0.0
    var latestFrame: UIImage?
    var longSide: CGFloat = 3
    var shortSide: CGFloat = 4
    var frameSizeCaptured = false
    
    var latestCroppedCarImage: UIImage?
    var latestCroppedPlateImage: UIImage?
    var lastCarPredictions: [VNRecognizedObjectObservation] = []
    
    let developerMode = UserDefaults.standard.bool(forKey: "developer_mode")
    let save_detections = false
    let save_frames = false
        var lastZoomFactor: CGFloat = 1.0

    private var isShowingCroppedView = false
    
    let maxBoundingBoxViews = 100
    var boundingBoxViews = [BoundingBoxView]()
    var colors: [String: UIColor] = [:]
    let ultralyticsColors: [UIColor] = [
        UIColor(red: 4/255, green: 42/255, blue: 255/255, alpha: 0.6),
        UIColor(red: 11/255, green: 219/255, blue: 235/255, alpha: 0.6),
        UIColor(red: 243/255, green: 243/255, blue: 243/255, alpha: 0.6),
        UIColor(red: 0/255, green: 223/255, blue: 183/255, alpha: 0.6),
        UIColor(red: 17/255, green: 31/255, blue: 104/255, alpha: 0.6),
        UIColor(red: 255/255, green: 111/255, blue: 221/255, alpha: 0.6),
        UIColor(red: 255/255, green: 68/255, blue: 79/255, alpha: 0.6),
        UIColor(red: 204/255, green: 237/255, blue: 0/255, alpha: 0.6),
        UIColor(red: 0/255, green: 243/255, blue: 68/255, alpha: 0.6),
        UIColor(red: 189/255, green: 0/255, blue: 255/255, alpha: 0.6),
        UIColor(red: 0/255, green: 180/255, blue: 255/255, alpha: 0.6),
        UIColor(red: 221/255, green: 0/255, blue: 186/255, alpha: 0.6),
        UIColor(red: 0/255, green: 255/255, blue: 255/255, alpha: 0.6),
        UIColor(red: 38/255, green: 192/255, blue: 0/255, alpha: 0.6),
        UIColor(red: 1/255, green: 255/255, blue: 179/255, alpha: 0.6),
        UIColor(red: 125/255, green: 36/255, blue: 255/255, alpha: 0.6),
        UIColor(red: 123/255, green: 0/255, blue: 104/255, alpha: 0.6),
        UIColor(red: 255/255, green: 27/255, blue: 108/255, alpha: 0.6),
        UIColor(red: 252/255, green: 109/255, blue: 47/255, alpha: 0.6),
        UIColor(red: 162/255, green: 255/255, blue: 11/255, alpha: 0.6),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        slider.value = 30
        setLabels()
        setUpBoundingBoxViews()
        setUpOrientationChangeNotification()
        
        title = "Video Feed"
        navigationItem.backButtonTitle = ""
        
        modelManager = ModelManager(viewController: self)
//        visionRequest = modelManager.visionRequest
//        licensePlateRequest = modelManager.licensePlateRequest
        
        videoCaptureManager.delegate = self
        videoCaptureManager.startVideo(videoPreview: videoPreview)
        
    }
    
    @IBAction private func toggleCroppedView() {
        selection.selectionChanged()
        print("Hovering tab button tapped in ViewController")
        let croppedVC = CroppedImagesViewController()
        navigationController?.pushViewController(croppedVC, animated: true)
        isShowingCroppedView = true
        hoveringTabButton.setImage(UIImage(systemName: "video"), for: .normal)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
                if size.width > size.height {
                    labelSliderConf.isHidden = true
                    sliderConf.isHidden = true
                    labelSliderIoU.isHidden = true
                    sliderIoU.isHidden = true
                    toolBar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
                    toolBar.setShadowImage(UIImage(), forToolbarPosition: .any)
        
                    labelSliderConfLandScape.isHidden = false
                    sliderConfLandScape.isHidden = false
                    labelSliderIoULandScape.isHidden = false
                    sliderIoULandScape.isHidden = false
                } else {
                    labelSliderConf.isHidden = false
                    sliderConf.isHidden = false
                    labelSliderIoU.isHidden = false
                    sliderIoU.isHidden = false
                    toolBar.setBackgroundImage(nil, forToolbarPosition: .any, barMetrics: .default)
                    toolBar.setShadowImage(nil, forToolbarPosition: .any)
        
                    labelSliderConfLandScape.isHidden = true
                    sliderConfLandScape.isHidden = true
                    labelSliderIoULandScape.isHidden = true
                    sliderIoULandScape.isHidden = true
                }
            videoCaptureManager.videoCapture.previewLayer?.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }
    
    private func setUpOrientationChangeNotification() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func orientationDidChange() {
        videoCaptureManager.videoCapture.updateVideoOrientation()
    }
    
    @IBAction func vibrate(_ sender: Any) { selection.selectionChanged() }
    
    @IBAction func indexChanged(_ sender: Any) {
        selection.selectionChanged()
        activityIndicator.startAnimating()
        labelName.text = ["YOLO11n", "YOLO11s", "YOLO11m", "YOLO11l", "YOLO11x"][segmentedControl.selectedSegmentIndex]
        modelManager.updateModel(index: segmentedControl.selectedSegmentIndex)
        setUpBoundingBoxViews()
        activityIndicator.stopAnimating()
    }
    
    @IBAction func sliderChanged(_ sender: Any) {
        let conf = Double(round(100 * sliderConf.value)) / 100
        let iou = Double(round(100 * sliderIoU.value)) / 100
        labelSliderConf.text = "\(conf) Confidence Threshold"
        labelSliderIoU.text = "\(iou) IoU Threshold"
        modelManager.detector.featureProvider = ThresholdProvider(iouThreshold: iou, confidenceThreshold: conf)
        modelManager.licensePlateDetector.featureProvider = ThresholdProvider(iouThreshold: iou, confidenceThreshold: conf)
    }
    
    @IBAction func takePhoto(_ sender: Any?) {
        let t0 = DispatchTime.now().uptimeNanoseconds
        let settings = AVCapturePhotoSettings()
        usleep(20_000)
        videoCaptureManager.videoCapture.cameraOutput.capturePhoto(with: settings, delegate: self)
        print("3 Done: ", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1E9)
    }
    
    @IBAction func logoButton(_ sender: Any) {
        selection.selectionChanged()
        if let link = URL(string: "https://www.ultralytics.com") {
            UIApplication.shared.open(link)
        }
    }
    
    func setLabels() {
        labelName.text = "YOLO11m"
        labelVersion.text = "RTTMAS Version " + (UserDefaults.standard.string(forKey: "app_version") ?? "")
    }
    
    @IBAction func playButton(_ sender: Any) {
        selection.selectionChanged()
        videoCaptureManager.videoCapture.start()
        playButtonOutlet.isEnabled = false
        pauseButtonOutlet.isEnabled = true
    }
    
    @IBAction func pauseButton(_ sender: Any?) {
        selection.selectionChanged()
        videoCaptureManager.videoCapture.stop()
        playButtonOutlet.isEnabled = true
        pauseButtonOutlet.isEnabled = false
    }
    
    @IBAction func switchCameraTapped(_ sender: Any) {
        videoCaptureManager.videoCapture.captureSession.beginConfiguration()
        let currentInput = videoCaptureManager.videoCapture.captureSession.inputs.first as? AVCaptureDeviceInput
        videoCaptureManager.videoCapture.captureSession.removeInput(currentInput!)
        guard let currentPosition = currentInput?.device.position else { return }
        let nextCameraPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        let newCameraDevice = bestCaptureDevice(for: nextCameraPosition)
        guard let videoInput1 = try? AVCaptureDeviceInput(device: newCameraDevice) else { return }
        videoCaptureManager.videoCapture.captureSession.addInput(videoInput1)
        videoCaptureManager.videoCapture.updateVideoOrientation()
        videoCaptureManager.videoCapture.captureSession.commitConfiguration()
    }
    
    @IBAction func shareButton(_ sender: Any) {
        selection.selectionChanged()
        let settings = AVCapturePhotoSettings()
        videoCaptureManager.videoCapture.cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @IBAction func saveScreenshotButton(_ shouldSave: Bool = true) {
        // Uncomment if needed
        //        // let layer = UIApplication.shared.keyWindow!.layer
        //        // let scale = UIScreen.main.scale
        //        // UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale);
        //        // layer.render(in: UIGraphicsGetCurrentContext()!)
        //        // let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        //        // UIGraphicsEndImageContext()
        //        // UIImageWriteToSavedPhotosAlbum(screenshot!, nil, nil, nil)
    }
    
    func setUpBoundingBoxViews() {
        while boundingBoxViews.count < maxBoundingBoxViews {
            boundingBoxViews.append(BoundingBoxView())
        }
        guard let classLabels = modelManager.mlModel.modelDescription.classLabels as? [String] else {
            fatalError("Class labels are missing from the model description")
        }
        var count = 0
        colors = [:]
        for label in classLabels {
            colors[label] = ultralyticsColors[count % ultralyticsColors.count]
            count += 1
        }
        colors["license_plate"] = UIColor(red: 255/255, green: 215/255, blue: 0/255, alpha: 0.6)
        for box in boundingBoxViews {
            box.addToLayer(videoPreview.layer)
        }
    }
    
    func show(predictions: [VNRecognizedObjectObservation], frame: UIImage?) {
        var str = ""
        let date = Date()
        let calendar = Calendar.current
        let sec_day = Double(calendar.component(.hour, from: date)) * 3600.0 +
                      Double(calendar.component(.minute, from: date)) * 60.0 +
                      Double(calendar.component(.second, from: date)) +
                      Double(calendar.component(.nanosecond, from: date)) / 1E9
        
        labelSlider.text = "\(predictions.count) items (max \(Int(slider.value)))"
        let width = Int(videoPreview.bounds.width)
        let height = Int(videoPreview.bounds.height)
        
        for i in 0..<boundingBoxViews.count {
            if i < predictions.count && i < Int(slider.value) {
                let prediction = predictions[i]
                let bestClass = prediction.labels[0].identifier.lowercased()
                let confidence = prediction.labels[0].confidence
                let rect = VNImageRectForNormalizedRect(prediction.boundingBox, width, height)
                var label = String(format: "%@ %.1f", bestClass, confidence * 100)
                if let ocrText = ocrResults[prediction.uuid.uuidString], !ocrText.isEmpty {
                    label += " \(ocrText)"
                }
                let alpha = CGFloat((confidence - 0.2) / (1.0 - 0.2) * 0.9)
                print("ViewController: Showing bounding box \(i) with label \(label) at \(rect)")
                boundingBoxViews[i].show(frame: rect, label: label, color: colors[bestClass] ?? .white, alpha: alpha)
            } else {
                // Only hide if not recently shown (handled by timer in BoundingBoxView)
//                boundingBoxViews[i].hide()
            }
        }
        
        if developerMode {
            if save_detections { Utilities.saveText(text: str, file: "detections.txt") }
            if save_frames {
                str = String(format: "%.3f %.3f %.3f %.3f %.1f %.1f %.1f\n",
                             sec_day, Utilities.freeSpace(), Utilities.memoryUsage(), UIDevice.current.batteryLevel,
                             t1 * 1000, t2 * 1000, 1 / t4)
                Utilities.saveText(text: str, file: "frames.txt")
            }
        }
        
        if t1 < 10.0 { t2 = t1 * 0.05 + t2 * 0.95 }
        t4 = (CACurrentMediaTime() - t3) * 0.05 + t4 * 0.95
        labelFPS.text = String(format: "%.1f FPS - %.1f ms", 1 / t4, t2 * 1000)
        t3 = CACurrentMediaTime()
    }
    
    func cropImage(_ image: UIImage, bbox: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage from UIImage")
            return nil
        }
        let imageWidth = Int(cgImage.width)
        let imageHeight = Int(cgImage.height)
        let cropRect = VNImageRectForNormalizedRect(bbox, imageWidth, imageHeight)
        let boundedRect = cropRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        guard boundedRect.width > 0, boundedRect.height > 0 else {
            print("Crop rect out of bounds or invalid: \(cropRect)")
            return nil
        }
        print("Cropping at: x=\(boundedRect.origin.x), y=\(boundedRect.origin.y), width=\(boundedRect.width), height=\(boundedRect.height)")
        if let croppedCGImage = cgImage.cropping(to: boundedRect) {
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
        print("Failed to crop CGImage at \(boundedRect)")
        return nil
    }
    
    func updateCroppedImagesTab() {
        NotificationCenter.default.post(
            name: NSNotification.Name("CroppedImagesUpdated"),
            object: nil,
            userInfo: ["history": ViewController.croppedHistory]
        )
    }
    
    @IBAction func pinch(_ pinch: UIPinchGestureRecognizer) {
        let device = videoCaptureManager.videoCapture.captureDevice
        let minimumZoom: CGFloat = 1.0
        let maximumZoom: CGFloat = 10.0
        
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }
        
        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        switch pinch.state {
        case .began, .changed:
            update(scale: newScaleFactor)
            labelZoom.text = String(format: "%.2fx", newScaleFactor)
            labelZoom.font = .preferredFont(forTextStyle: .title2)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
            labelZoom.font = .preferredFont(forTextStyle: .body)
        default: break
        }
    }
    
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Failed to render CIImage to CGImage")
            return
        }
        let image = UIImage(cgImage: cgImage)
        DispatchQueue.main.async { self.latestFrame = image }
        detectionManager.predict(sampleBuffer: sampleBuffer)
    }
}


