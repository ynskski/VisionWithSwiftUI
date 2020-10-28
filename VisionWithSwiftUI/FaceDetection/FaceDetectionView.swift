//
//  FaceDetectionView.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import SwiftUI

struct FaceDetectionView: View {
    @ObservedObject private var viewModel = FaceDetectionViewModel()
    
    var body: some View {
        ZStack {
            CALayerView(caLayer: viewModel.previewLayer)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("傾き: \(viewModel.faceRoll), 回転: \(viewModel.faceYaw)")
                
                Spacer()
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        FaceDetectionView()
    }
}
