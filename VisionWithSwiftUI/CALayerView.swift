//
//  CALayerView.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import SwiftUI

struct CALayerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    var caLayer: CALayer
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.layer.addSublayer(caLayer)
        caLayer.frame = viewController.view.layer.frame
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        caLayer.frame = uiViewController.view.layer.frame
    }
}
