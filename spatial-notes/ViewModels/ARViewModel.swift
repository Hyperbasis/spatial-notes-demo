//
//  ARViewModel.swift
//  spatial-notes
//

import SwiftUI
import RealityKit
import Combine
import simd

/// Manages app state and coordinates between AR and UI
@MainActor
class ARViewModel: ObservableObject {

    // MARK: - Properties

    /// The AR session manager
    let arManager: ARSessionManager

    /// All placed notes
    @Published private(set) var notes: [StickyNote] = []

    /// Currently selected note (for editing)
    @Published var selectedNote: StickyNote?

    /// Whether the note input sheet is showing
    @Published var isShowingNoteInput: Bool = false

    /// Pending note position (where user tapped)
    @Published var pendingNotePosition: SIMD3<Float>?

    /// Pending note orientation
    @Published var pendingNoteOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    /// Map of note IDs to their entities
    private var noteEntities: [UUID: StickyNoteEntity] = [:]

    // MARK: - Initialization

    init() {
        arManager = ARSessionManager()
        setupTapGesture()
    }

    // MARK: - Gesture Handling

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arManager.arView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arManager.arView)

        // First, check if tapped on an existing note
        if let hitEntity = arManager.arView.entity(at: location) {
            // Walk up the parent chain to find StickyNoteEntity
            var entity: Entity? = hitEntity
            while let current = entity {
                if let noteEntity = current as? StickyNoteEntity {
                    if let note = notes.first(where: { $0.id == noteEntity.noteId }) {
                        selectedNote = note
                    }
                    return
                }
                entity = current.parent
            }
        }

        // Otherwise, raycast to find surface
        if let result = arManager.raycast(from: location) {
            pendingNotePosition = result.position
            pendingNoteOrientation = orientationFromNormal(result.normal)
            isShowingNoteInput = true
        }
    }

    /// Converts a surface normal to an orientation quaternion
    private func orientationFromNormal(_ normal: SIMD3<Float>) -> simd_quatf {
        // Default "forward" direction
        let forward = SIMD3<Float>(0, 0, 1)

        // Calculate rotation from forward to normal
        let dot = simd_dot(forward, normal)
        let cross = simd_cross(forward, normal)

        if dot < -0.999999 {
            // Vectors are opposite
            return simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
        }

        let q = simd_quatf(
            ix: cross.x,
            iy: cross.y,
            iz: cross.z,
            r: 1 + dot
        )

        return simd_normalize(q)
    }

    // MARK: - Note Operations

    /// Creates a new note at the pending position
    func createNote(text: String, color: NoteColor = .yellow) {
        guard let position = pendingNotePosition else { return }

        let note = StickyNote(
            text: text,
            color: color,
            position: position,
            orientation: pendingNoteOrientation
        )

        notes.append(note)

        // Create and add entity
        let entity = StickyNoteEntity(note: note)
        noteEntities[note.id] = entity
        arManager.addEntity(entity, at: position)

        // Reset pending state
        pendingNotePosition = nil
        isShowingNoteInput = false
    }

    /// Updates an existing note's text
    func updateNote(_ note: StickyNote, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        notes[index].text = text

        // Update entity
        noteEntities[note.id]?.updateText(text)
    }

    /// Updates an existing note's color
    func updateNoteColor(_ note: StickyNote, color: NoteColor) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        notes[index].color = color

        // Update entity
        noteEntities[note.id]?.updateColor(color)
    }

    /// Deletes a note
    func deleteNote(_ note: StickyNote) {
        notes.removeAll { $0.id == note.id }

        // Remove entity
        if let entity = noteEntities[note.id] {
            arManager.removeEntity(entity)
            noteEntities.removeValue(forKey: note.id)
        }

        selectedNote = nil
    }

    /// Cancels note creation
    func cancelNoteCreation() {
        pendingNotePosition = nil
        isShowingNoteInput = false
    }

    /// Deselects the current note
    func deselectNote() {
        selectedNote = nil
    }
}
