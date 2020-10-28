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
            if faceDetectionViewModel.image == nil {
                CALayerView(caLayer: faceDetectionViewModel.previewLayer)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        FaceDetectionView()
    }
}
