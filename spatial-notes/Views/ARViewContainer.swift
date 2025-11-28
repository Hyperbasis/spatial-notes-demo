//
//  ARViewContainer.swift
//  spatial-notes
//

import SwiftUI
import RealityKit

/// UIViewRepresentable wrapper for ARView
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARViewModel

    func makeUIView(context: Context) -> ARView {
        viewModel.arManager.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No updates needed - viewModel handles everything
    }
}
