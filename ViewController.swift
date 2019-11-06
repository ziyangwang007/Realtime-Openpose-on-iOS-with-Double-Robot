

import UIKit
import CoreML
import AVFoundation
private var key: Void?

class ViewController: UIViewController {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var outputLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var infoLabel1: UILabel!
    @IBOutlet weak var runOpenPoseButton: UIButton!
    @IBOutlet weak var shouldFollowPersonSwitch: UISwitch!
    // Drive Buttons
    @IBOutlet weak var driveForwardButton: UIButton!
    @IBOutlet weak var driveBackwardButton: UIButton!
    @IBOutlet weak var driveLeftButton: UIButton!
    @IBOutlet weak var driveRightButton: UIButton!
    
    // MARK: - UI Actions
    
    @IBAction func runOpenPoseAction(_ sender: Any) {
        runOpenPoseButton.isSelected = !runOpenPoseButton.isSelected
        isReadyToRunOpenPose = runOpenPoseButton.isSelected
        if runOpenPoseButton.isSelected {
            UIView.animate(withDuration: 0.4) {
                self.cameraHelper.start(self.camera)
                self.runOpenPoseButton.setTitle("Stop", for: .normal)
                self.runOpenPoseButton.backgroundColor = #colorLiteral(red: 0.01864526048, green: 0.4776622653, blue: 1, alpha: 1)
            }
        } else {
            UIView.animate(withDuration: 0.4) {
                self.cameraHelper.stop(self.camera)
                self.runOpenPoseButton.setTitle("Start", for: .normal)
                self.runOpenPoseButton.backgroundColor = #colorLiteral(red: 0.1317750514, green: 0.5311791897, blue: 0.9966103435, alpha: 1)
            }
            self.drawLayer.removeFromSuperlayer()
        }
    }
    
    // Pole
    @IBAction func poleUpAction(_ sender: Any) {
        doubleController?.poleUp()
    }
    @IBAction func poleStopAction(_ sender: Any) {
        doubleController?.poleStop()
    }
    @IBAction func poleDownAction(_ sender: Any) {
        doubleController?.poleDown()
    }
    
    // Kickstands
    @IBAction func kickstandsRetractAction(_ sender: Any) {
        doubleController?.retractKickstands()
    }
    @IBAction func kickstandsDeployAction(_ sender: Any) {
        doubleController?.deployKickstands()
    }
    // Head Power
    @IBAction func headPowerOnAction(_ sender: Any) {
        doubleController?.headPowerOn()
    }
    @IBAction func headPowerOffAction(_ sender: Any) {
        doubleController?.headPowerOff()
    }
    // Encoders
    @IBAction func encodersStartAction(_ sender: Any) {
        doubleController?.startTravelData()
    }
    @IBAction func encodersStopAction(_ sender: Any) {
        doubleController?.stopTravelData()
    }
    
    // MARK: - CoreML Properties
    
    let model = MobileOpenPose()
    let imageWidth: CGFloat = 368
    let imageHeight: CGFloat = 368
    var drawLayer: CALayer!
    
    var isReadyToRunOpenPose: Bool = false
    
    // MARK: - CameraKit Property
    
    let cameraHelper = CameraHelper()
    let camera = DRCameraKit.shared()
    
    // MARK: - DoubleController Property
    
    let doubleController = DRDouble.shared()
    
    // Move Properties
    
    var shouldMoveForward: Bool = false
    var shouldTurnLeft: Bool = false    
    var shouldTurnRight: Bool = false
    
    // MARK: - Status bar
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDrawLayer()
        configureCamera()
        configureDoubleController()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Setup Draw Layer
    
    func setupDrawLayer() {
        drawLayer = CALayer()
        drawLayer.frame = imageView.bounds
        drawLayer.opacity = 0.6
        drawLayer.masksToBounds = true
    }
    
    // MARK: - CoreML Methods
    
    func runCoreML(_ image: UIImage) {
        
        if let pixelBuffer = image.pixelBuffer(width: Int(imageWidth), height: Int(imageHeight)) {
            
            let startTime = CFAbsoluteTimeGetCurrent()
            if let prediction = try? model.prediction(image: pixelBuffer) {
                
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("coreml elapsed for \(timeElapsed) seconds")
                
               let predictionOutput = prediction.net_output
               let length = predictionOutput.count
               print(predictionOutput)
                
                let doublePointer =  predictionOutput.dataPointer.bindMemory(to: Double.self, capacity: length)
                let doubleBuffer = UnsafeBufferPointer(start: doublePointer, count: length)
                let mm = Array(doubleBuffer)
                
                // Delete Beizer paths of previous image
                drawLayer.removeFromSuperlayer()
                // Draw new lines
                drawLines(mm)
                
                isReadyToRunOpenPose = true
            }
        }
    }
    
    // MARK: - Drawing
    
    func drawLines(_ mm: Array<Double>){
        
        let poseEstimator = PoseEstimator(Int(imageWidth), Int(imageHeight))
        
        let res = measure(poseEstimator.estimate(mm))
        let humans = res.result;
        print("estimate \(res.duration)")
        
        var keypoint = [Int32]()
        var pos = [CGPoint]() {
            didSet {
                if shouldFollowPersonSwitch.isOn {
                    calculateMovements(pos)
                } else {
                    shouldMoveForward = false
                    shouldTurnLeft = false
                    shouldTurnRight = false
                }
            }
        }
        
        for human in humans {
            var centers = [Int: CGPoint]()
            for i in 0...CocoPart.Background.rawValue {
                if human.bodyParts.keys.index(of: i) == nil {
                    continue
                }
                let bodyPart = human.bodyParts[i]!
                centers[i] = CGPoint(x: bodyPart.x, y: bodyPart.y)
            }
            
            for (pairOrder, (pair1,pair2)) in CocoPairsRender.enumerated() {
                
                if human.bodyParts.keys.index(of: pair1) == nil || human.bodyParts.keys.index(of: pair2) == nil {
                    continue
                }
                if centers.index(forKey: pair1) != nil && centers.index(forKey: pair2) != nil{
                    keypoint.append(Int32(pairOrder))
                    pos.append(centers[pair1]!)
                    pos.append(centers[pair2]!)
                }
            }
        }
        
        let openCVWrapper = OpenCVWrapper()
        
        if let renderedImage = openCVWrapper.renderKeyPoint(imageView.frame,
                                                            keypoint: &keypoint,
                                                            keypoint_size: Int32(keypoint.count),
                                                            pos: &pos) {
            drawLayer.contents = renderedImage.cgImage
        }
        
        imageView.layer.addSublayer(drawLayer)
        
    }
    
    // MARK: - Movement Calculations
    
    func calculateMovements(_ pos: [CGPoint]) {
        var xRange: CGFloat = 0 {
            didSet {
                shouldMoveForward = xRange <= 0.3
            }
        }
        
        var averageXPos: CGFloat = 0 {
            didSet {
                shouldTurnLeft = averageXPos <= 0.35
                shouldTurnRight = averageXPos >= 0.65
            }
        }
        
        if !pos.isEmpty {
            let posXArray = pos.map{ $0.x }
            if let average = posXArray.average {
                averageXPos = average
            }
            if let max = posXArray.max(),
               let min = posXArray.min() {
                xRange = abs(max - min)
            }
        } else {
            shouldMoveForward = false
            shouldTurnLeft = false
            shouldTurnRight = false
        }
    }
    
    // MARK: - Help Methods
    
    func measure <T> (_ f: @autoclosure () -> T) -> (result: T, duration: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = f()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, "Elapsed time is \(timeElapsed) seconds.")
    }
    
}

extension ViewController: DRCameraKitImageDelegate, DRCameraKitConnectionDelegate {
    var myImage: UIImage? {
        get {
            return objc_getAssociatedObject(self, &key) as? UIImage
        }
        set(newValue) {
            objc_setAssociatedObject(self, &key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    func configureCamera() {
        camera?.connectionDelegate = self
        camera?.imageDelegate = self
        cameraHelper.configureQuality(camera)
    }
    
    func cameraKit(_ theKit: DRCameraKit!, didReceive theImage: UIImage!, sizeInBytes length: Int) {
        
        imageView.image = theImage
        self.myImage = theImage

        if runOpenPoseButton.isSelected {
            if isReadyToRunOpenPose {
                isReadyToRunOpenPose = false
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5 ) {
                    self.myImage = CameraTool.resizeImage(self.myImage!, newWidthX: self.imageWidth, newHeightX: self.imageWidth)
                    self.imageView.image = self.myImage
                    self.outputLabel.text = self.measure(self.runCoreML(self.myImage!)).duration
                }
            }
            else {
                imageView.image = theImage
            }
        }
        
    }
    
    func cameraKitConnectionStatusDidChange(_ theKit: DRCameraKit!) {
        let statusString = theKit.isConnected() ? "Camera is connected" : "Camera is not Connected"
        outputLabel.text = statusString
    }
    
}

extension ViewController: DRDoubleDelegate {
    
    func configureDoubleController() {
        doubleController?.delegate = self
    }
    
    func doubleDriveShouldUpdate(_ theDouble: DRDouble!) {
        let drive: DRDriveDirection = (shouldMoveForward ? true : driveForwardButton.isHighlighted) ? DRDriveDirection.forward : ((driveBackwardButton.isHighlighted) ? DRDriveDirection.backward : DRDriveDirection.stop)
        var turn: Float = (shouldTurnRight ? true : driveRightButton.isHighlighted) ? 1.0 : ((shouldTurnLeft ? true : driveLeftButton.isHighlighted) ? -1.0 : 0.0)
        turn = turn * 0.65
        theDouble.drive(drive, turn: turn)
    }
    
    func doubleDidConnect(_ theDouble: DRDouble!) {
        infoLabel.text = "Double Controller is connected"
    }
    
    func doubleDidDisconnect(_ theDouble: DRDouble!) {
        infoLabel.text = "Double Controller is not connected"
    }
    func doubleStatusDidUpdate(_ theDouble: DRDouble!) {
        infoLabel1.text = "Battery: \(theDouble.batteryPercent), leftEncoder: \(theDouble.leftEncoderDeltaInches), rightEncoder: \(theDouble.rightEncoderDeltaInches)"
    }
    

}

