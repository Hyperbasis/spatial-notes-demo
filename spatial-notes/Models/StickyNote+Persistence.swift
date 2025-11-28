//
//  StickyNote+Persistence.swift
//  spatial-notes
//

import Foundation
import simd
import Hyperbasis

extension StickyNote {

    /// Creates a StickyNote from an HBAnchor
    init?(from anchor: HBAnchor) {
        // Extract metadata
        guard let text = anchor.stringMetadata(forKey: "text") else {
            return nil
        }

        let colorString = anchor.stringMetadata(forKey: "color") ?? "yellow"
        let color = NoteColor(rawValue: colorString) ?? .yellow

        // Extract position from transform
        let position = anchor.position

        // Extract orientation from transform
        let orientation: simd_quatf
        if let transform = anchor.validSimdTransform {
            // Extract rotation from transform matrix
            let rotationMatrix = simd_float3x3(
                SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
            )
            orientation = simd_quatf(rotationMatrix)
        } else {
            orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }

        self.init(
            id: anchor.id,
            text: text,
            color: color,
            position: position,
            orientation: orientation,
            createdAt: anchor.createdAt
        )
    }

    /// Converts to metadata dictionary for HBAnchor
    func toMetadata() -> [String: AnyCodableValue] {
        return [
            "text": .string(text),
            "color": .string(color.rawValue),
            "type": .string("sticky_note")
        ]
    }

    /// Creates a simd_float4x4 transform from position and orientation
    var simdTransform: simd_float4x4 {
        // Create rotation matrix from quaternion
        let rotationMatrix = simd_matrix4x4(orientation)

        // Set translation
        var transform = rotationMatrix
        transform.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)

        return transform
    }
}

// Helper to create 4x4 matrix from quaternion
private func simd_matrix4x4(_ q: simd_quatf) -> simd_float4x4 {
    let n = simd_normalize(q)

    let xx = n.imag.x * n.imag.x
    let xy = n.imag.x * n.imag.y
    let xz = n.imag.x * n.imag.z
    let xw = n.imag.x * n.real

    let yy = n.imag.y * n.imag.y
    let yz = n.imag.y * n.imag.z
    let yw = n.imag.y * n.real

    let zz = n.imag.z * n.imag.z
    let zw = n.imag.z * n.real

    return simd_float4x4(
        SIMD4<Float>(1 - 2 * (yy + zz), 2 * (xy + zw), 2 * (xz - yw), 0),
        SIMD4<Float>(2 * (xy - zw), 1 - 2 * (xx + zz), 2 * (yz + xw), 0),
        SIMD4<Float>(2 * (xz + yw), 2 * (yz - xw), 1 - 2 * (xx + yy), 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}
