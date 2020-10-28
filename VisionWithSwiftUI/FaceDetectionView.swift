//
//  FaceDetectionView.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import SwiftUI

struct FaceDetectionView: View {
    @ObservedObject private var faceDetectionViewModel = FaceDetectionViewModel()
    
    var body: some View {
        ZStack {
            CALayerView(caLayer: faceDetectionViewModel.previewLayer)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("傾き: \(faceDetectionViewModel.faceRoll), 回転: \(faceDetectionViewModel.faceYaw)")
                
                Spacer()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        FaceDetectionView()
    }
}
