//
//  HomeView.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import SwiftUI

struct HomeView: View {
    @State private var isFaceDetectionViewPresented = false
    
    var body: some View {
        VStack {
            Button("顔検出") {
                isFaceDetectionViewPresented.toggle()
            }
        }
        .sheet(isPresented: $isFaceDetectionViewPresented) {
            FaceDetectionView()
        }
    }
}

struct HomeViwe_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
