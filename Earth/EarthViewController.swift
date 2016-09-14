//
//  EarthViewController.swift
//  Earth
//
//  Created by Evan Bacon on 9/13/16.
//  Copyright (c) 2016 Brix. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import CoreLocation
import GLKit
import AVFoundation
class EarthViewController: UIViewController {
    let speechSynthesizer = AVSpeechSynthesizer()
    
    var pinNode:SCNNode!
    var earthNode:SCNNode!
    var geocoder = CLGeocoder()
//    var speech:NSSpeechSynthesizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene()
        self.view.backgroundColor = UIColor(white: 0.05, alpha: 1)

        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 8)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = SCNLightTypeOmni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        ambientLightNode.light!.color = UIColor.darkGrayColor()
        scene.rootNode.addChildNode(ambientLightNode)
        
        
        let earth = SCNSphere(radius: 3)
        let material = SCNMaterial()
        
        material.diffuse.contents = UIImage(named: "earth_diffuse_4k")
        material.specular.contents = UIImage(named: "earth_specular_1k")
        material.emission.contents = UIImage(named: "earth_lights_4k")
        material.normal.contents = UIImage(named: "earth_normal_4k")
        material.multiply.contents = UIColor(white:  0.7, alpha: 1)
        material.shininess = 0.05

        earth.firstMaterial = material
        
        
        
        let earthNode = SCNNode(geometry: earth)
        // tilt the earth
        let axisNode = SCNNode()
        scene.rootNode.addChildNode(axisNode)
        axisNode.addChildNode(earthNode)
        axisNode.rotation = SCNVector4Make(1, 0, 0, Float(M_PI/6));
        
        self.earthNode = earthNode;
        
        
        // Create a larger sphere to look like clouds
        let clouds = SCNSphere(radius: 3.075)
        clouds.segmentCount = 144; // 3 times the default
        let cloudsMaterial = SCNMaterial()
        
        cloudsMaterial.diffuse.contents = UIColor.whiteColor()
        cloudsMaterial.locksAmbientWithDiffuse = true
        // Use a texture where RGB (or lack thereof) determines transparency of the material
        cloudsMaterial.transparent.contents = UIImage(named: "clouds_transparent_2K")
        cloudsMaterial.transparencyMode = SCNTransparencyMode.RGBZero;
        
        // Don't have the clouds cast shadows
        cloudsMaterial.writesToDepthBuffer = false;
        
        // ------------------
        // This is a "shader modifier" to create an atmospheric halo effect.
        // We won't go into shader modifiers until Chapter 13. But it adds a nice
        // visual effect to this example.
        let url = NSBundle.mainBundle().pathForResource("AtmosphereHalo", ofType: "glsl")
//        NSError *error;
        
        do {
            if let url = url {
            let shaderSource = try NSString(contentsOfURL: NSURL(fileURLWithPath: url), encoding: NSUTF8StringEncoding)
                
//        if !shaderSource {
//            // Handle the error
//            NSLog("Failed to load shader source code, with error: %@", [error localizedDescription]);
//        } else {
            cloudsMaterial.shaderModifiers = [SCNShaderModifierEntryPointFragment : shaderSource as String]
            }
//        }
        // ------------------
        } catch {
            
        }
        clouds.firstMaterial = cloudsMaterial;
        let cloudNode = SCNNode(geometry: clouds)
        
        earthNode.addChildNode(cloudNode)
        
        earthNode.rotation = SCNVector4Make(0, 1, 0, 0); // specify the rataion axis
        cloudNode.rotation = SCNVector4Make(0, 1, 0, 0); // specify the rataion axis
        
        // Animate the rotation of the earth and the clouds
        // ------------------------------------------------
        let rotate = CABasicAnimation(keyPath:"rotation.w") // animate the angle
        rotate.byValue   = M_PI * 2.0
        rotate.duration  = 50.0;
        rotate.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        rotate.repeatCount = Float.infinity;
        
        earthNode.addAnimation(rotate, forKey: "rotate the earth")
        
        let rotateClouds = CABasicAnimation(keyPath: "rotation.w") // animate the angle
        rotateClouds.byValue   = -M_PI * 2.0
        rotateClouds.duration  = 150.0;
        rotateClouds.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        rotateClouds.repeatCount = Float.infinity;
        
        cloudNode.addAnimation(rotateClouds, forKey:"slowly move the clouds")
        
        
        // Create something to light up the earth.
        let sun    = SCNLight()
        sun.type = SCNLightTypeSpot
        
        // Configure the shadows that the sun casts
        sun.castsShadow  = true;
        sun.shadowRadius = 3.0;
        sun.shadowColor  = UIColor.blackColor().colorWithAlphaComponent(0.75)
        
//        sun.setValue(10, SCNLightShadowNearClippingKey)
//        sun.setValue(40, SCNLightShadowFarClippingKey)
        
        let sunNode = SCNNode()
        sunNode.light    = sun;
        
        // Position the sun to the left
        sunNode.position = SCNVector3Make(-15, 0, 12);
        
        // Made the sun point at the earth
        sunNode.constraints = [SCNLookAtConstraint(target: earthNode)];
        scene.rootNode.addChildNode(sunNode)
        setupPinNode()
        
        
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = UIColor.blackColor()
        
        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
    }
    
    func handleTap(gestureRecognize: UIGestureRecognizer) {
        
//        SCNHitTestRootNodeKey: self.earthNode,
//        SCNHitTestIgnoreChildNodesKey: @YES
        
        
        // Get the location of the click
        
        // Get the hit on the earth
        
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // check what nodes are tapped
        let p = gestureRecognize.locationInView(scnView)
        let hitResults = scnView.hitTest(p, options: [
            SCNHitTestRootNodeKey: self.earthNode,
            SCNHitTestIgnoreChildNodesKey: true
            ])
        // check that we clicked on at least one object
        
        guard hitResults.count > 0 else { return }
        
        // retrieved the first clicked object
        let result: SCNHitTestResult! = hitResults[0]
            

        
        // Use the texture coordinate to approximate a location
        let textureCoordinate = result.textureCoordinatesWithMappingChannel(0);
        let location = self.coordinateFromPoint(textureCoordinate)
        
        self.geocoder.reverseGeocodeLocation(location,
            completionHandler: {
                placemarks, error in
                
                if let place = placemarks?.first {
            
                    let placeName = place.name ?? place.country ?? place.ocean ?? place.inlandWater ?? "No where"
                    
                    self.speechSynthesizer.speakUtterance(AVSpeechUtterance(string: placeName))

                    print(placeName)
//                    self.speech.startSpeakingString(placeName)
                }
            });
        
        
        // Calcualte how to rotate the pin so that it points in the
        // same direction as the surface normal at that location.
        let pinDirection = GLKVector3Make(0.0, 1.0, 0.0);
        let normal       = SCNVector3ToGLKVector3(result.localNormal);
        
        let rotationAxis = GLKVector3CrossProduct(pinDirection, normal);
        let    cosAngle     = GLKVector3DotProduct(pinDirection, normal);
        
        let rotation = GLKVector4MakeWithVector3(rotationAxis, acos(cosAngle));
        
        SCNTransaction.begin()
        SCNTransaction.setAnimationDuration(0.5)
        
        // Position the hit where the user clicked
        self.pinNode.position = result.localCoordinates;
        self.pinNode.rotation = SCNVector4FromGLKVector4(rotation);

        SCNTransaction.commit()
        
        
  
        
//
//        // retrieve the SCNView
//        let scnView = self.view as! SCNView
//        
//        // check what nodes are tapped
//        let p = gestureRecognize.locationInView(scnView)
//        let hitResults = scnView.hitTest(p, options: nil)
//        // check that we clicked on at least one object
//        if hitResults.count > 0 {
//            // retrieved the first clicked object
//            let result: AnyObject! = hitResults[0]
//            
//            // get its material
//            let material = result.node!.geometry!.firstMaterial!
//            
//            // highlight it
//            SCNTransaction.begin()
//            SCNTransaction.setAnimationDuration(0.5)
//            
//            // on completion - unhighlight
//            SCNTransaction.setCompletionBlock {
//                SCNTransaction.begin()
//                SCNTransaction.setAnimationDuration(0.5)
//                
//                material.emission.contents = UIColor.blackColor()
//                
//                SCNTransaction.commit()
//            }
//            
//            material.emission.contents = UIColor.redColor()
//            
//            SCNTransaction.commit()
//        }
    }
    
    
    
    func setupPinNode() -> SCNNode
    {
    
    // Create a pin with a red head just like the bars in Chapter 3
    // (a pin node that hold both the body node and the head node)
    
    let bodyHeight:CGFloat = 0.3;
    let bodyRadius:CGFloat = 0.019;
        let headRadius:CGFloat = 0.06;
    
    // Create a cylinder and a sphere
        let body = SCNCylinder(radius: bodyRadius, height: bodyHeight)
        let head = SCNSphere(radius: headRadius)
    
    // Create and assign the two materials
    let headMaterial = SCNMaterial()
    let bodyMaterial = SCNMaterial()
    
    headMaterial.diffuse.contents = UIColor.redColor()
    headMaterial.emission.contents = UIColor(red:0.2, green:0, blue:0, alpha:1.0)
    bodyMaterial.specular.contents = UIColor.whiteColor()
    bodyMaterial.emission.contents = UIColor(red:0.1, green:0.1, blue:0.1, alpha:1.0)
    headMaterial.specular.contents = UIColor.whiteColor()
    bodyMaterial.shininess = 100;
    
    head.firstMaterial = headMaterial;
    body.firstMaterial = bodyMaterial;
    
    // Create and position the two nodes
    let bodyNode = SCNNode(geometry: body)
    bodyNode.position = SCNVector3Make(0, Float(bodyHeight)/2.0, 0);
    let headNode = SCNNode(geometry: head)
    headNode.position = SCNVector3Make(0, Float(bodyHeight), 0);
    
    // Add them both to the pin node
    let pinNode = SCNNode()
    pinNode.addChildNode(bodyNode)
    pinNode.addChildNode(headNode)
    
    // Add to the earth
    self.earthNode.addChildNode(pinNode)
    
    self.pinNode = pinNode
    return pinNode
    }

    func coordinateFromPoint(point:CGPoint) -> CLLocation
    {
    let u = point.x;
    let v = point.y;
    
        let lat:CLLocationDegrees = Double(0.5 - v) * 180.0;
        let lon:CLLocationDegrees = Double(u - 0.5) * 360.0;
    
    return CLLocation(latitude: lat, longitude: lon)
    }
    
    
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            return .AllButUpsideDown
        } else {
            return .All
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

}
