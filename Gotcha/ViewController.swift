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
    @IBOutlet weak var restoreBtn: UIButton!
    @IBOutlet weak var saveBtn: UIButton!
    
    public var isHost = false
    
    private var multipeerSession: MultipeerSession!
    
    private var target: ARItem!
    
    private lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()

    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var doubletapGestureRecognizer: UITapGestureRecognizer!

    public var mapProvider: MCPeerID?
    
    lazy var listViewController: ItemListCollectionViewController = {
        let listViewController = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CollectionView") as! ItemListCollectionViewController
        return listViewController
    }()
    
    // host: saving & restore the currentWorldMap
    var worldMapURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("worldMapURL")
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
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
        restoreBtn.isHidden = !isHost
        saveBtn.isHidden = !isHost
        restoreBtn.isEnabled = retrieveWorldMapData(from: worldMapURL) != nil
        // setup P2P
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        
        // setup user feedback
        setupContainerView()
        
        // setup gesture recognizer
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapped))
        tapGestureRecognizer.numberOfTapsRequired = 1
        doubletapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapped))
        doubletapGestureRecognizer.numberOfTapsRequired = 2
        tapGestureRecognizer.require(toFail: doubletapGestureRecognizer)
        
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        sceneView.addGestureRecognizer(doubletapGestureRecognizer)

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
    
    @IBAction func saveBtnHandler(_ sender: UIButton) {
        saveCurrentWorldMap()
    }
    
    @IBAction func restoreBtnHandler(_ sender: UIButton) {
        guard let worldMapData = retrieveWorldMapData(from: worldMapURL),
            let worldMap = unarchive(worldMapData: worldMapData) else { return }
        restore(worldMap: worldMap)
    }
    
    // MARK: - Item List View
    private var itemListHeightConstraint: NSLayoutConstraint!

    private func setupContainerView() {
        addChild(listViewController)
        listViewController.delegate = self
        
        listViewController.view.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(listViewController.view)
        sceneView.bringSubviewToFront(listViewController.view)
        
        itemListHeightConstraint = listViewController.view.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            listViewController.view.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor),
            listViewController.view.rightAnchor.constraint(equalTo: sceneView.rightAnchor),
            listViewController.view.leftAnchor.constraint(equalTo: sceneView.leftAnchor),
            itemListHeightConstraint
            ])

    }
    
    @objc func handleTapped(_ notification: UITapGestureRecognizer) {
        sceneView.removeGestureRecognizer(tapGestureRecognizer)
        itemListHeightConstraint.constant =  200
        
        UIView.animate(withDuration: 0.8) {
            self.view.layoutIfNeeded()
            self.detectBtn.isHidden = true
            self.listViewController.collectionView.reloadData()
        }
    }
    
    @objc func handleDoubleTapped(_ notification: UITapGestureRecognizer) {
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        itemListHeightConstraint.constant = 0

        UIView.animate(withDuration: 0.8) {
            self.view.layoutIfNeeded()
            self.detectBtn.isHidden = false
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
        if ItemModel.shared.getList().isEmpty { return }
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
        resetTrackingConfiguration()
        
        // Set a delegate to track the number of plane anchors for providing UI feedback.
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Show debug UI to view performance metrics (e.g. frames per second).
//        sceneView.showsStatistics = true
//        sceneView.debugOptions = [.showFeaturePoints]
    }
    
    private func resetTrackingConfiguration(worldMap: ARWorldMap? = nil) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.initialWorldMap = worldMap
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        
        sceneView.session.run(configuration, options: options)
    }
    
    private func saveCurrentWorldMap() {
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let worldMap = worldMap else { return }
            
            do {
                try self.archive(worldMap: worldMap)
            } catch {
                fatalError("Error saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    private func restore(worldMap: ARWorldMap) {
        resetTrackingConfiguration(worldMap: worldMap)
        // re-add ItemModel
        for anchor in worldMap.anchors {
            if let name = anchor.name, !name.isEmpty {
                ItemModel.shared.addItem(name: identifierString, anchor: anchor)
            }
        }
    }
    
    private func retrieveWorldMapData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: self.worldMapURL)
        } catch {
            print("Error retrieving world map data.")
            return nil
        }
    }
    
    // Archive and Unarchive WorldMap
    private func archive(worldMap: ARWorldMap) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try data.write(to: self.worldMapURL, options: [.atomic])
    }
    
    private func unarchive(worldMapData data: Data) -> ARWorldMap? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
            let worldMap = unarchievedObject else { return nil }
        return worldMap
    }
    
    /// add ARAnchor onto current plane
    public func placeObjectNode() {
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        guard let hitTestResult = sceneView.hitTest(screenCentre, types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane]).first else { return }
    
        // Place an anchor for a virtual character.
        let anchor = ARAnchor(name: identifierString, transform: hitTestResult.worldTransform)
        sceneView.session.add(anchor: anchor)
        
        print("adding item:", identifierString)
        // add to item model
        ItemModel.shared.addItem(name: identifierString, anchor: anchor)
        
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

        return nil
    }

}

// MARK: - Vision Task
extension ViewController {
    
    // Host can tag item when objection recognition is not working
    private func tagByUserInput() {
        let title = "UNIDENTIFIED"
        let msg = "Please enter the item"
        
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (_) in
            if let textField = alert.textFields?.first, let value = textField.text {
                self.identifierString = value
                self.placeObjectNode()
            }
        }
        let cancel = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        
        alert.addAction(cancel)
        alert.addAction(ok)
        
        // show the alert in the main thread
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
        
    }

    
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
            
            DispatchQueue.main.async { [weak self] in
                self?.displayClassifierResults()
            }
            
        }
        
        else {
            identifierString = ""
            confidence = 0
            tagByUserInput()
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
//                Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { (_) in
//                    self.shareARWorldMap()
//                }
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
            resetTrackingConfiguration(worldMap: worldMap)
            
            // re-add ItemModel
            for anchor in worldMap.anchors {
                if let name = anchor.name, !name.isEmpty {
                    ItemModel.shared.addItem(name: identifierString, anchor: anchor)
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
        itemListHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
            self.detectBtn.isHidden = false
        }
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    public func showDirection(of object: ARItem) {

        guard let pointOfView = sceneView.pointOfView else { return }
        
        // remove previous instruction
        for node in pointOfView.childNodes {
            node.removeFromParentNode()
        }
        
        // target
        let desNode = SCNNode()
        let targetPoint = SCNVector3.positionFromTransform(object.anchor.transform)
        desNode.worldPosition = targetPoint
        
        // guide
        let startPoint = SCNVector3(0, 0 , -1.0)
        let guideNode = loadObject()
        guideNode.scale = SCNVector3(0.7, 0.7, 0.7)
        guideNode.position = startPoint
        
        let lookAtConstraints = SCNLookAtConstraint(target: desNode)
        lookAtConstraints.isGimbalLockEnabled = true
        // Here's the magic
        guideNode.pivot = SCNMatrix4Rotate(guideNode.pivot, Float.pi, 0, 1, 1)
        
        guideNode.constraints = [lookAtConstraints]
        pointOfView.addChildNode(guideNode)
    }
    
}
