//
//  HomeView.swift
//  VisionWithSwiftUI
//
//  Created by YunosukeSakai on 2020/10/28.
//

import SwiftUI

struct HomeView: View {
    @State private var isFaceDetectionViewPresented = false
    @State private var isRectangleDetectionViewPresented = false
    
    var body: some View {
        VStack {
            Button("顔検出") {
                isFaceDetectionViewPresented.toggle()
            }
            .sheet(isPresented: $isFaceDetectionViewPresented) {
                FaceDetectionView()
            }
            .padding()
            
            Button("矩形検出") {
                isRectangleDetectionViewPresented.toggle()
            }
            .sheet(isPresented: $isRectangleDetectionViewPresented) {
                RectangleDetectionView()
            }
            .padding()
        }
    }
}

struct HomeViwe_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
