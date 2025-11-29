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
                // Use distinct icon instead of colored circle
                Image(systemName: trackingIcon)
                    .foregroundColor(trackingColor)
                    .font(.system(size: 10, weight: .bold))
                Text("DEV MODE")
                    .font(.caption.bold())
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Tracking State
            Group {
                debugRow("Tracking", trackingStateText, color: trackingColor)
                debugRow("Planes", "\(arManager.planeCount)", color: .white)
                debugRow("Anchors", "\(arManager.anchorCount)", color: .white)
                debugRow("Notes", "\(noteCount)", color: .white)
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Frame Info
            Text(arManager.frameInfo)
                .font(.system(size: 10, design: .monospaced))

            Divider()
                .background(Color.white.opacity(0.3))

            // Legend - more accurate descriptions
            VStack(alignment: .leading, spacing: 2) {
                Text("AR Visualizations:")
                    .font(.caption2.bold())
                legendRow(color: .yellow, text: "Feature points (tracking)")
                legendRow(colors: [.red, .green, .blue], text: "World origin (RGB=XYZ)")
                legendRow(colors: [.red, .green, .blue], text: "Anchor axes (RGB=XYZ)")
                legendRow(color: Color(red: 0.3, green: 0.8, blue: 0.3), text: "Plane mesh (surfaces)")
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Log Console
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Console:")
                        .font(.caption2.bold())
                    Spacer()
                    Text("\(arManager.logs.count) logs")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(arManager.logs.suffix(20).enumerated()), id: \.offset) { index, log in
                                LogRow(log: log)
                                    .id(index)
                            }
                        }
                    }
                    .frame(height: 100)
                    .onChange(of: arManager.logs.count) {
                        withAnimation {
                            proxy.scrollTo(min(19, arManager.logs.count - 1), anchor: .bottom)
                        }
                    }
                }
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.white)
        .padding(10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .frame(width: 220)
    }

    private func debugRow(_ label: String, _ value: String, color: Color = .white) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
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

    private func legendRow(colors: [Color], text: String) -> some View {
        HStack(spacing: 4) {
            HStack(spacing: 1) {
                ForEach(colors.indices, id: \.self) { i in
                    Circle()
                        .fill(colors[i])
                        .frame(width: 4, height: 4)
                }
            }
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
        case .normal: return .mint  // Changed from green to mint
        case .limited: return .orange
        case .notAvailable: return .red
        }
    }

    private var trackingIcon: String {
        switch arManager.trackingState {
        case .normal: return "checkmark.circle.fill"
        case .limited: return "exclamationmark.triangle.fill"
        case .notAvailable: return "xmark.circle.fill"
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    enum LogLevel: String {
        case debug = "DBG"
        case info = "INF"
        case warning = "WRN"
        case error = "ERR"

        var color: Color {
            switch self {
            case .debug: return .gray
            case .info: return .cyan
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
}

struct LogRow: View {
    let log: LogEntry

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: log.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(timeString)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Text(log.level.rawValue)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(log.level.color)
            Text(log.message)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
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
