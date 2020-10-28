//
//  RectangleDetectionView.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import SwiftUI

struct RectangleDetectionView: View {
    @ObservedObject var viewModel = RectangleDetectionViewModel()
    
    var body: some View {
        CALayerView(caLayer: viewModel.previewLayer)
            .onAppear {
                viewModel.startSession()
            }
            .onDisappear {
                viewModel.stopSession()
            }
    }
}

struct IdDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        RectangleDetectionView()
    }
}
