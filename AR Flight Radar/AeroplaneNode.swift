//
//  AeroplaneNode.swift
//  AR Flight Radar
//
//  Created by Richard Nelson on 2/10/21.
//

import Foundation
import ARKit

class AeroplaneNode: SCNNode {
    var data: Aeroplane
    var originalColour: UIColor?
    
    init(geometry: SCNGeometry?, data: Aeroplane) {
        self.data = data
        super.init()
        self.geometry = geometry
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
