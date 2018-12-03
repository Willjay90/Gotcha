//
//  ViewController.swift
//  Gotcha
//
//  Created by Wei Chieh Tseng on 10/2/18.
//  Copyright © 2018 Wei Chieh Tseng. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision
import MultipeerConnectivity

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sendMapButton: UIButton!
    @IBOutlet weak var sessionInfoView: UIVisualEffectView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var detectBtn: UIButton!
    
    public var isHost = false
    
    private var multipeerSession: MultipeerSession!
    
    private var target: arItemList!
    
    private lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()

    private var tapGestureRecognizer: UITapGestureRecognizer!
    
    public var mapProvider: MCPeerID?
    
    // TAG: - Vision classification
    private lazy var classificationRequest: VNCoreMLRequest = {
        do {
            // Instantiate the model from its generated Swift class.
            let model = try VNCoreMLModel(for: Inceptionv3().model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            
            // Crop input images to square area at center, matching the way the ML model was trained.
            request.imageCropAndScaleOption = .centerCrop
            
            // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
            request.usesCPUOnly = true
            
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    public var currentBuffer: CVPixelBuffer?
    
    // Queue for dispatching vision classification requests
    private let visionQueue = DispatchQueue(label: "com.example.apple-samplecode.ARKitVision.serialVisionQueue")
    
    
    // Classification results
    private var identifierString = ""
    private var confidence: VNConfidence = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()
        detectBtn.isHidden = !isHost
        
        // setup P2P
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        
        // setup user feedback
        setupListTableView()
        
        // setup gesture recognizer
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapped))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's AR session
        sceneView.session.pause()
    }
    
    // MARK: - Item List View
    private var tableViewHeightConstraints: NSLayoutConstraint!
    private func setupListTableView() {
        let listViewTableViewController = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ItemList") as! ItemListTableViewController
        self.addChild(listViewTableViewController)
        listViewTableViewController.delegate = self
        
        listViewTableViewController.view.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(listViewTableViewController.view)
        sceneView.bringSubviewToFront(listViewTableViewController.view)
        
        tableViewHeightConstraints = listViewTableViewController.view.heightAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            listViewTableViewController.view.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor),
            listViewTableViewController.view.rightAnchor.constraint(equalTo: sceneView.rightAnchor),
            listViewTableViewController.view.leftAnchor.constraint(equalTo: sceneView.leftAnchor),
            tableViewHeightConstraints
            ])
    }
    
    @objc func handleTapped(_ notification: UITapGestureRecognizer) {
        tableViewHeightConstraints.constant = sceneView.frame.height - 100
        sceneView.removeGestureRecognizer(tapGestureRecognizer)
        UIView.animate(withDuration: 0.8) {
            self.view.layoutIfNeeded()
            self.detectBtn.isHidden = true
        }
    }
    
    @IBAction func shareSession(_ sender: UIButton) {
        shareARWorldMap()
    }
    
    @IBAction func detectObject(_ sender: UIButton) {
        classifyCurrentImage()
    }
    
    @IBAction func resetGuidence(_ sender: UIButton) {
        for node in sceneView.pointOfView!.childNodes {
            node.removeFromParentNode()
        }
    }
    
    private func shareARWorldMap() {
        if ItemModel.shared.anchors.isEmpty { return }
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
    }
    
    private func startARSession() {
        // Start the view's AR session with a configuration that uses the rear camera,
        // device position and orientation tracking, and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
        
        // Set a delegate to track the number of plane anchors for providing UI feedback.
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Show debug UI to view performance metrics (e.g. frames per second).
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    /// add ARAnchor onto current plane
    public func placeObjectNode() {
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        guard let hitTestResult = sceneView.hitTest(screenCentre, types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane]).first else { return }
    
        // Place an anchor for a virtual character.
        let anchor = ARAnchor(name: identifierString, transform: hitTestResult.worldTransform)
        sceneView.session.add(anchor: anchor)
        // add to item model
        ItemModel.shared.anchors.append((identifierString, anchor))

        
        // Send the anchor info to peers, so they can place the same content.
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else { fatalError("can't encode anchor") }
        self.multipeerSession.sendToAllPeers(data)
        
    }
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if let name = anchor.name, !name.isEmpty {
            // Create 3D Text
            let textNode: SCNNode = createNewBubbleParentNode(name)
            return textNode
        }

//        if let name = anchor.name, name == "guide", target != nil {
//            let desNode = SCNNode()
//            desNode.position = SCNVector3.positionFromTransform(target.1.transform)
//            print("O=HOAL")
//
//            let guideNode = loadObject()
//            guideNode.scale = SCNVector3(0.8, 0.8, 0.8)
//            let lookAtConstraints = SCNLookAtConstraint(target: desNode)
//            lookAtConstraints.isGimbalLockEnabled = true
//            guideNode.constraints = [lookAtConstraints]
//            return guideNode
//        }

        return nil
    }

}

// MARK: - Vision Task
extension ViewController {
    
    // Run the Vision+ML classifier on the current image buffer.
    public func classifyCurrentImage() {
        guard let currentBuffer = self.currentBuffer else { return }
        
        // Most computer vision tasks are not rotation agnostic so it is important to pass in the orientation of the image with respect to device.
        let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: currentBuffer, orientation: orientation)
        
        visionQueue.async {
            do {
                try requestHandler.perform([self.classificationRequest])
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.currentBuffer = nil }
            } catch {
                print("Error: Vision request failed with error \"\(error)\"")
            }
        }
    }
    
    // Handle completion of the Vision request and choose results to display.
    func processClassifications(for request: VNRequest, error: Error?) {
        guard let results = request.results else {
            print("Unable to classify image.\n\(error!.localizedDescription)")
            return
        }
        // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
        let classifications = results as! [VNClassificationObservation]
        
        // Show a label for the highest-confidence result (but only above a minimum confidence threshold).
        if let bestResult = classifications.first(where: { result in result.confidence > 0.5 }),
            let label = bestResult.identifier.split(separator: ",").first {
            identifierString = String(label)
            confidence = bestResult.confidence
        } else {
            identifierString = ""
            confidence = 0
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.displayClassifierResults()
        }
    }
    
    // Show the classification results in the UI.
    private func displayClassifierResults() {
        guard !self.identifierString.isEmpty else { return } // No object was classified.
        let message = String(format: "Detected \(self.identifierString) with %.2f", self.confidence * 100) + "% confidence"
        statusViewController.showMessage(message)
    }
}

// MARK: - ARSessionDelegate
extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
  
        if case .normal = frame.camera.trackingState {
            detectBtn.isEnabled = true
        } else {
            detectBtn.isEnabled = false
        }

        // Retain the image buffer for Vision processing.
        self.currentBuffer = frame.capturedImage

    }
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move around to map the environment, or wait to join a shared session."
            
        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."
            
            if isHost {
                sendMapButton.isHidden = multipeerSession.connectedPeers.isEmpty
                Timer.scheduledTimer(withTimeInterval: 3000, repeats: false) { (_) in
                    self.shareARWorldMap()
                }
            }
            
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
            
        case .limited(.relocalizing):
            message = "Resuming session — move to where you were when the session was interrupted."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            
        }
        
        self.sessionInfoLabel.text = message
        self.sessionInfoView.isHidden = message.isEmpty
        
    }
}

extension ViewController {
    /// - Tag: ReceiveData
    func receivedData(_ data: Data, from peer: MCPeerID) {
        if let unarchived = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [ARWorldMap.classForKeyedArchiver()!], from: data),
            let worldMap = unarchived as? ARWorldMap {
            // Remember who provided the map for showing UI feedback.
            mapProvider = peer
            print("Received Data From Peer", peer.displayName)
            
            // Run the session with the received world map.
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.initialWorldMap = worldMap
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            for anchor in worldMap.anchors {
                if let name = anchor.name, !name.isEmpty {
                    ItemModel.shared.anchors.append((name, anchor))
                }
            }
            
        }
        else {
            print("unknown data recieved from \(peer)")
        }
    }
}

// MARK : - Handle Item List
extension ViewController: ItemListDragProtocol {
    private func loadObject() -> SCNNode {
        // MARK: - AR session management
        let sceneURL = Bundle.main.url(forResource: "ArrowB", withExtension: "scn", subdirectory: "art.scnassets")!
        let referenceNode = SCNReferenceNode(url: sceneURL)!
        referenceNode.load()
        return referenceNode
    }
    
    // https://github.com/hanleyweng/CoreML-in-ARKit
    private func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        let font = UIFont(name: "Futura", size: 0.15)
        bubble.font = font
        bubble.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // BUBBLE PARENT NODE
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        return bubbleNodeParent
    }
    
    public func closeItemList() {
        tableViewHeightConstraints.constant = 0
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
            self.detectBtn.isHidden = false
        }
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    /// TODO: It's not right :(, need to modify
    public func showDirection(of object: arItemList) {
        
//            let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
//            guard let hitTestResult = sceneView.hitTest(screenCentre, types: [.featurePoint]).first else { return }
//            let startPoint = SCNVector3.positionFromTransform(hitTestResult.worldTransform)
        
        let targetPoint = SCNVector3.positionFromTransform(object.1.transform)
        
        let g = SCNSphere(radius: 0.01)
        g.firstMaterial?.diffuse.contents = UIColor.red
        let desNode = SCNNode(geometry: g)
        desNode.worldPosition = targetPoint
        sceneView.scene.rootNode.addChildNode(desNode)
        
        
//            let anchor = ARAnchor(name: "guide", transform: hitTestResult.worldTransform)
//            sceneView.session.add(anchor: anchor)
//            target = object
//            sceneView.scene.rootNode.addChildNode(guideNode)
        
        let startPoint = SCNVector3(0, 0 , -1.0)
        let guideNode = loadObject()
        guideNode.scale = SCNVector3(0.5, 0.5, 0.5)
        guideNode.position = startPoint
        let lookAtConstraints = SCNLookAtConstraint(target: desNode)
        lookAtConstraints.isGimbalLockEnabled = true
        guideNode.constraints = [lookAtConstraints]
        
        sceneView.pointOfView?.addChildNode(guideNode)
    }
    
}
