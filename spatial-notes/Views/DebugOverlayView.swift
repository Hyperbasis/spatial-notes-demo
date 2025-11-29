//
//  DebugOverlayView.swift
//  spatial-notes
//

import SwiftUI
import ARKit

struct DebugOverlayView: View {
    @ObservedObject var arManager: ARSessionManager
    let noteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Circle()
                    .fill(trackingColor)
                    .frame(width: 8, height: 8)
                Text("DEV MODE")
                    .font(.caption.bold())
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Tracking State
            Group {
                debugRow("Tracking", trackingStateText)
                debugRow("Planes", "\(arManager.planeCount)")
                debugRow("Anchors", "\(arManager.anchorCount)")
                debugRow("Notes", "\(noteCount)")
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Frame Info
            Text(arManager.frameInfo)
                .font(.system(size: 10, design: .monospaced))

            Divider()
                .background(Color.white.opacity(0.3))

            // Legend
            VStack(alignment: .leading, spacing: 2) {
                Text("Visualizations:")
                    .font(.caption2.bold())
                legendRow(color: .yellow, text: "Feature points")
                legendRow(color: .red, text: "World origin")
                legendRow(color: .cyan, text: "Anchor origins")
                legendRow(color: .green, text: "Plane geometry")
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.white)
        .padding(10)
        .background(Color.black.opacity(0.75))
        .cornerRadius(8)
        .frame(width: 180)
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var trackingStateText: String {
        switch arManager.trackingState {
        case .normal:
            return "Normal"
        case .limited(let reason):
            switch reason {
            case .initializing: return "Initializing"
            case .excessiveMotion: return "Moving too fast"
            case .insufficientFeatures: return "Low features"
            case .relocalizing: return "Relocalizing"
            @unknown default: return "Limited"
            }
        case .notAvailable:
            return "Not Available"
        }
    }

    private var trackingColor: Color {
        switch arManager.trackingState {
        case .normal: return .green
        case .limited: return .orange
        case .notAvailable: return .red
        }
    }
}

struct DebugToggleButton: View {
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text("D")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isEnabled ? .black : .white)
                .frame(width: 32, height: 32)
                .background(isEnabled ? Color.yellow : Color.black.opacity(0.6))
                .cornerRadius(8)
        }
    }
}
