/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import SafariServices

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var mapView: UIView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.flatMap({ $0 as? StatusViewController }).first!
    }()
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.alpha = 0.5
        mapView.backgroundColor = UIColor.clear
        
        let imageView = UIImageView.init(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 50.0))
        imageView.image = UIImage.init(named: "map")
        imageView.contentMode = UIViewContentMode.scaleToFill
        
        mapView.addSubview(imageView)
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.rendersContinuously = true
        
        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
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
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal
        configuration.detectionImages = referenceImages
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
	}

    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        renderer.showsStatistics = true
        guard let imageAnchor = anchor as? ARImageAnchor else {
            return
        }
        
        let referenceImage = imageAnchor.referenceImage
        updateQueue.async {
            
            var imageName = referenceImage.name ?? ""
            var planeWidth = referenceImage.physicalSize.width
            var planeHeight = referenceImage.physicalSize.height/2
            var offsetZ = -referenceImage.physicalSize.width
            if imageName == "1" {
                imageName = "arrow"
                planeWidth = referenceImage.physicalSize.width * 2
                planeHeight = referenceImage.physicalSize.height * 2
                offsetZ = 0
            } else {
                imageName = "test"
            }
            
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: planeWidth,
                                 height: planeHeight)
//
            let material = SCNMaterial()
            material.isDoubleSided = false
                
            let image = UIImage(named: imageName)
            material.diffuse.contents = image
//            material.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
            plane.materials = [material]
            
            let planeNode = SCNNode(geometry: plane)
            
            planeNode.position = SCNVector3(0,0,offsetZ)
            planeNode.opacity = 1.0
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
//            planeNode.runAction(self.imageHighlightAction)
            
            // Add the plane visualization to the scene.
            if imageName == "arrow" {
                planeNode.runAction(self.imageHighlightAction)
            }
            node.addChildNode(planeNode)
            
            let cc = SCNTransformConstraint.positionConstraint(inWorldSpace: true, with: { (node_tmp,position_tmp ) -> SCNVector3 in
                return node.position
            })
            let rr = SCNTransformConstraint.orientationConstraint(inWorldSpace: true, with: { (node_tmp, qu_tmp) -> SCNQuaternion in
                return node.orientation
            })

            node.constraints = [cc,rr]
        }

        DispatchQueue.main.async {
            let imageName = referenceImage.name ?? ""
            print("fuck ", imageName)
            self.statusViewController.cancelAllScheduledMessages()
            if imageName == "1" {
                self.statusViewController.showMessage("Detected image")
            }
            else {
                self.statusViewController.showMessage("fuck")
            }
        }
        //self.resetTracking()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor)
    {
        print("willUpdate node", node.scale)
//        let animation = CABasicAnimation(keyPath:"scale")
//        animation.fromValue = node.scale
//        animation.toValue = SCNVector3(1.0,1.0,1.0)
//        animation.duration = 0.2
//        animation.repeatCount = 0
//        node.addAnimation(animation, forKey: "fuck")
//        node.scale = SCNVector3(1.0,1.0,1.0)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor)
    {
        print("didUpdate node", node.scale)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor)
    {
        print("didRemove node")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: sceneView)

        var hitTestOptions = [SCNHitTestOption: Any]()
        hitTestOptions[SCNHitTestOption.boundingBoxOnly] = true
        let hitResults: [SCNHitTestResult]  =
            sceneView.hitTest(location, options: hitTestOptions)
        if hitResults.first != nil {
            print("fuck")
            let url = NSURL(string: "https://www.ikea.com/hk/zh/catalog/products/60162301/")
            let safariVC = SFSafariViewController(url: url! as URL)
            self.show(safariVC, sender: nil)
            hitResults.first?.node.removeFromParentNode()
            return
            //https://www.ikea.com/hk/zh/catalog/products/60162301/
        }
    }
    
    var imageHighlightAction: SCNAction {
//        var action = SCNAction.sequence([
//            .wait(duration: 0.1),
//            .fadeOpacity(to: 0.85, duration: 0.25),
//            .fadeOpacity(to: 0.15, duration: 0.25),
//            .fadeOpacity(to: 0.85, duration: 0.25),
//            ])
        var action = SCNAction.sequence([
            .wait(duration: 0.1),
            .moveBy(x: 0.0, y: 0.0, z: -0.15, duration: 1.0),
            .moveBy(x: 0.0, y: 0.0, z: 0.15, duration: 0.0),
            ])
        return SCNAction.repeatForever(action)
    }
}
