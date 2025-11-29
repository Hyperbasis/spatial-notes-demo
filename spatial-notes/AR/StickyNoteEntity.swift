//
//  StickyNoteEntity.swift
//  spatial-notes
//

import RealityKit
import UIKit

/// A RealityKit entity representing a sticky note in AR
class StickyNoteEntity: Entity, HasModel, HasCollision {

    /// The note data this entity represents
    let noteId: UUID

    /// Size of the sticky note in meters
    static let noteSize: Float = 0.08  // 8cm

    // MARK: - Initialization

    /// Creates a sticky note entity
    /// Note: Position is handled by the anchor - don't set world position here
    required init(note: StickyNote) {
        self.noteId = note.id
        super.init()

        setupVisuals(text: note.text, color: note.color)
        setupCollision()

        // Make the note always face the camera (billboard effect)
        self.components.set(BillboardComponent())
    }

    @MainActor required init() {
        self.noteId = UUID()
        super.init()
    }

    // MARK: - Setup

    private func setupVisuals(text: String, color: NoteColor) {
        // Create note mesh (flat box)
        let mesh = MeshResource.generateBox(
            width: Self.noteSize,
            height: Self.noteSize,
            depth: 0.002  // 2mm thick
        )

        // Create material with note color
        var material = SimpleMaterial()
        material.color = .init(tint: color.uiColor, texture: nil)
        material.roughness = 0.8
        material.metallic = 0.0

        self.model = ModelComponent(mesh: mesh, materials: [material])

        // Add text as child entity
        addTextLabel(text: text)
    }

    private func addTextLabel(text: String) {
        // Limit text length for display
        let displayText = String(text.prefix(50))

        // Create text mesh
        let textMesh = MeshResource.generateText(
            displayText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.008, weight: .medium),
            containerFrame: CGRect(x: -0.035, y: -0.035, width: 0.07, height: 0.07),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        var textMaterial = SimpleMaterial()
        textMaterial.color = .init(tint: .black, texture: nil)

        let textEntity = Entity()
        textEntity.components.set(ModelComponent(mesh: textMesh, materials: [textMaterial]))

        // Position text slightly in front of note
        textEntity.position = SIMD3<Float>(0, 0, 0.002)
        textEntity.name = "textLabel"

        self.addChild(textEntity)
    }

    private func setupCollision() {
        // Add collision for tap detection
        let shape = ShapeResource.generateBox(
            width: Self.noteSize,
            height: Self.noteSize,
            depth: 0.01
        )
        self.collision = CollisionComponent(shapes: [shape])
    }

    // MARK: - Updates

    /// Updates the note's text
    func updateText(_ text: String) {
        // Remove old text entity
        for child in children where child.name == "textLabel" {
            child.removeFromParent()
        }
        addTextLabel(text: text)
    }

    /// Updates the note's color
    func updateColor(_ color: NoteColor) {
        var material = SimpleMaterial()
        material.color = .init(tint: color.uiColor, texture: nil)
        material.roughness = 0.8
        material.metallic = 0.0

        self.model?.materials = [material]
    }
}
