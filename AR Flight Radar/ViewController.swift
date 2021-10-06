//
//  ViewController.swift
//  AR Flight Radar
//
//  Created by Richard Nelson on 24/9/21.
//

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    // The view controller that displays the HUD
    var hudViewController: HUDViewController?
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    private var hudNode: SCNNode?
    private var imageAnchorNode: SCNNode?
    private var referenceImage: ARReferenceImage?
    private var trailNode: SCNNode?
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.hudViewController = self.storyboard?.instantiateViewController(withIdentifier: "hudViewController") as? HUDViewController
        
        sceneView.delegate = self
        sceneView.session.delegate = self

        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
        setupHudNode()
        setupStatusHandlers()
    }
    
    private func setupHudNode() {
        let plane = SCNPlane(width: 0.16, height: 0.07)
        let view = self.hudViewController?.view.subviews.first
        self.hudViewController?.view.isOpaque = false
        view?.layer.cornerRadius = 10
        view?.layer.borderColor = UIColor(red: 0.7, green: 0.0, blue: 0.0, alpha: 0.8).cgColor
        view?.layer.borderWidth = 2
        plane.firstMaterial?.diffuse.contents = view
        plane.firstMaterial?.isDoubleSided = true //required if you place the camera behind the view
        self.hudNode = SCNNode(geometry: plane)
        self.hudNode?.eulerAngles.x = -.pi / 4
        self.hudNode?.opacity = 0
        self.hudNode?.name = "hudNode"
    }
       
    private func setupStatusHandlers() {
        statusViewController.callsignHandler = { callSign in
            self.getFlights(callSign: callSign ?? "")
        }
        
        statusViewController.flightNumberHandler = { number in
            if number == "" {
                self.removeTrails()
                self.imageAnchorNode?.childNodes.forEach { node in
                    node.opacity = 1.0
                }
                self.hudNode?.opacity = 0.0
                return
            }
            self.imageAnchorNode?.childNodes.forEach { node in
                guard let planeNode = node as? AeroplaneNode else { return }
                if (planeNode.data.call.lowercased() == number?.lowercased()) {
                    node.opacity = 1
                    self.hudNode?.simdPosition = SIMD3<Float>.init(x: node.simdPosition.x, y: node.simdPosition.y + 0.01, z: node.simdPosition.z - 0.08)
                    self.hudNode?.opacity = 0.95
                    AeroplaneData().getFlightInfo(plane: planeNode.data) { flightStatus in
                        DispatchQueue.main.async {
                            self.hudViewController?.setData(status: flightStatus)
                            self.hudNode?.simdPosition = SIMD3<Float>.init(x: node.simdPosition.x, y: node.simdPosition.y + 0.01, z: node.simdPosition.z - 0.08)
                            self.hudNode?.opacity = 1.0
                            self.drawFlightTrail(flightData: flightStatus)
                        }
                    }
                } else {
                    node.opacity = 0.2
                }
            }
        }
    }
    
    private func removeTrails() {
        imageAnchorNode?.childNodes.filter { $0.name == "trail" }.forEach { $0.removeFromParentNode() }
    }
    
    private func getFlights(callSign: String) {
        guard let referenceImage = referenceImage,
              let imageAnchorNode = imageAnchorNode else {
            return
        }
        
        removeTrails()
        
        AeroplaneData().getRealtimePositioning(callSign: callSign) { [self] aeroplanes in
            imageAnchorNode.childNodes.filter { $0 != self.hudNode }.forEach { $0.removeFromParentNode() }
            aeroplanes.forEach { aircraft in
                let material = SCNMaterial()
                material.diffuse.contents = UIImage(named: "plane")
                let geometry = SCNPlane(width: 0.003, height: 0.003)
                geometry.materials = [material]
                let planeNode = AeroplaneNode(geometry: geometry, data: aircraft)
                planeNode.originalColour = material.diffuse.contents as? UIColor
                let x = Float(referenceImage.physicalSize.width / 360 * CGFloat(180 + aircraft.lon)) - Float(referenceImage.physicalSize.width / 2)
                let z = Float(referenceImage.physicalSize.height / 180 * CGFloat(90 - aircraft.lat)) - Float(referenceImage.physicalSize.height / 2)
                var y: Float = 0.005
                y = Float(aircraft.altitude) * 0.00000002
                planeNode.simdPosition =  SIMD3<Float>.init(x: x, y: y, z: z)
                planeNode.eulerAngles.y = (Float(-aircraft.heading) * Float.pi / 180)
                planeNode.eulerAngles.x = -.pi / 2
                imageAnchorNode.addChildNode(planeNode)
                planeNode.name = "plane"
                print("Flight \(aircraft.call) heading \(aircraft.heading)")
            }
        }
    }
    
    func drawFlightTrail(flightData: FlightData) {
        guard let referenceImage = referenceImage else {
            return
        }
        
        removeTrails()
       
        for (index, point) in flightData.trail.enumerated() {
            if (index < flightData.trail.count - 1) {
                let point2 = flightData.trail[index + 1]
                let x1 = Float(referenceImage.physicalSize.width / 360 * CGFloat(180 + point.lng)) - Float(referenceImage.physicalSize.width / 2)
                let z1 = Float(referenceImage.physicalSize.height / 180 * CGFloat(90 - point.lat)) - Float(referenceImage.physicalSize.height / 2)
                let x2 = Float(referenceImage.physicalSize.width / 360 * CGFloat(180 + point2.lng)) - Float(referenceImage.physicalSize.width / 2)
                let z2 = Float(referenceImage.physicalSize.height / 180 * CGFloat(90 - point2.lat)) - Float(referenceImage.physicalSize.height / 2)
                let y1 = Float(point.alt) * 0.00000002
                let y2 = Float(point2.alt) * 0.00000002
                let sphere = SCNSphere(radius: 0.000002)
                let mat = SCNMaterial()
                mat.diffuse.contents = UIColor.red
                sphere.materials = [mat]
                let node = cylVector(from: SCNVector3Make(x1, y1, z1), to: SCNVector3Make(x2, y2, z2), radius: 0.0003, material: mat)
                //node.simdPosition = SIMD3.init(x: x, y: y, z: z)
                if let node = node {
                    self.imageAnchorNode?.addChildNode(node)
                    node.name = "trail"
                }
            }
        }
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "mappin.and.ellipse")
        let geometry = SCNPlane(width: 0.007, height: 0.007)
        geometry.materials = [material]
        let x = Float(referenceImage.physicalSize.width / 360 * CGFloat(180 + flightData.airport.destination.position.longitude)) - Float(referenceImage.physicalSize.width / 2)
        let z = Float(referenceImage.physicalSize.height / 180 * CGFloat(90 - flightData.airport.destination.position.latitude)) - Float(referenceImage.physicalSize.height / 2)
        let y: Float = 0.00002
        let node = SCNNode(geometry: geometry)
        node.simdPosition = SIMD3.init(x: x, y: y, z: z)
        node.name = "trail"
        node.eulerAngles.x = -.pi / 4
        self.imageAnchorNode?.addChildNode(node)
    }
    
    func cylVector(from : SCNVector3, to : SCNVector3, radius: CGFloat, material: SCNMaterial) -> SCNNode? {
        let vector = to - from,
        length = vector.length()
        if (length > 0.2) {
            return nil
        }
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        cylinder.radialSegmentCount = 12
        cylinder.firstMaterial = material

        let node = SCNNode(geometry: cylinder)

        node.position = (to + from) / 2
        node.eulerAngles = SCNVector3Make(Float(CGFloat(Double.pi/2)), acos((to.z-from.z)/length), atan2((to.y-from.y), (to.x-from.x) ))

        return node
   }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR experience
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        session.pause()
    }

    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true

    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
    func resetTracking() {
        
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARImageTrackingConfiguration()
        configuration.trackingImages = referenceImages
        configuration.isAutoFocusEnabled = true
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
    }

    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        self.imageAnchorNode = node
        let referenceImage = imageAnchor.referenceImage
        self.referenceImage = referenceImage
            
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.25
            
            /*
             `SCNPlane` is vertically oriented in its local coordinate space, but
             `ARImageAnchor` assumes the image is horizontal in its local space, so
             rotate the plane to match.
             */
            planeNode.eulerAngles.x = -.pi / 2
            
            /*
             Image anchors are not tracked after initial detection, so create an
             animation that limits the duration for which the plane visualization appears.
             */
            planeNode.runAction(self.imageHighlightAction)
            
            // Add the plane visualization to the scene.
            node.addChildNode(planeNode)
            
            getFlights(callSign: "")

        if let hudNode = hudNode {
            node.addChildNode(hudNode)
        }

        DispatchQueue.main.async {
            let imageName = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image “\(imageName)”")
        }
    }

    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }
}
