//
//  StickyNote.swift
//  spatial-notes
//

import Foundation
import simd
import UIKit

/// Represents a sticky note placed in AR space
struct StickyNote: Identifiable, Equatable {
    /// Unique identifier
    let id: UUID

    /// The note's text content
    var text: String

    /// Background color of the note
    var color: NoteColor

    /// Position in world space (x, y, z in meters)
    var position: SIMD3<Float>

    /// Rotation as quaternion
    var orientation: simd_quatf

    /// When the note was created
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        color: NoteColor = .yellow,
        position: SIMD3<Float>,
        orientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.position = position
        self.orientation = orientation
        self.createdAt = createdAt
    }
}

/// Available sticky note colors
enum NoteColor: String, CaseIterable {
    case yellow
    case pink
    case blue
    case green

    var uiColor: UIColor {
        switch self {
        case .yellow: return UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 1.0)
        case .pink: return UIColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)
        case .blue: return UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1.0)
        case .green: return UIColor(red: 0.7, green: 1.0, blue: 0.75, alpha: 1.0)
        }
    }
}
