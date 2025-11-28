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

    /// Persistence manager for saving/loading
    let persistence: PersistenceManager

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

    /// Whether we have an active space
    @Published var hasActiveSpace: Bool = false

    /// Whether notes have been loaded
    @Published var notesLoaded: Bool = false

    /// Map of note IDs to their entities
    private var noteEntities: [UUID: StickyNoteEntity] = [:]

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        arManager = ARSessionManager()
        persistence = PersistenceManager()
        setupTapGesture()
        setupSubscriptions()

        // Try to load existing space on launch
        Task {
            await loadExistingSpace()
        }

        // Listen for save world map notifications
        NotificationCenter.default.addObserver(
            forName: .saveWorldMap,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.saveWorldMap()
            }
        }
    }

    private func setupSubscriptions() {
        // When relocalization completes, load the notes
        arManager.$isRelocalized
            .filter { $0 }
            .sink { [weak self] _ in
                Task {
                    await self?.loadNotesAfterRelocalization()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    /// Loads existing space and attempts relocalization
    private func loadExistingSpace() async {
        do {
            if let space = try await persistence.loadMostRecentSpace() {
                hasActiveSpace = true

                // Get the world map and relocalize
                let worldMap = try space.arWorldMap()
                arManager.relocalize(with: worldMap)

                // Notes will be loaded after relocalization completes
            }
        } catch {
            print("Failed to load space: \(error)")
            // No existing space - start fresh
        }
    }

    /// Loads notes after successful relocalization
    private func loadNotesAfterRelocalization() async {
        do {
            let loadedNotes = try await persistence.loadNotes()

            // Create entities for each note
            for note in loadedNotes {
                let entity = StickyNoteEntity(note: note)
                noteEntities[note.id] = entity
                arManager.addEntity(entity, at: note.position)
            }

            self.notes = loadedNotes
            self.notesLoaded = true
        } catch {
            print("Failed to load notes: \(error)")
        }
    }

    /// Creates or updates the space with current world map
    func saveWorldMap() async {
        guard arManager.canCaptureWorldMap else { return }

        do {
            let worldMap = try await arManager.getCurrentWorldMap()

            if persistence.currentSpace == nil {
                // First note - create space
                _ = try await persistence.createSpace(name: nil, worldMap: worldMap)
                hasActiveSpace = true
            } else {
                // Update existing space
                try await persistence.updateSpace(worldMap: worldMap)
            }
        } catch {
            print("Failed to save world map: \(error)")
        }
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

        // Save to persistence
        Task {
            // Save world map first (creates space if needed)
            await saveWorldMap()

            // Then save the note
            do {
                try await persistence.saveNote(note)
            } catch {
                print("Failed to save note: \(error)")
            }
        }
    }

    /// Updates an existing note's text
    func updateNote(_ note: StickyNote, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        notes[index].text = text
        noteEntities[note.id]?.updateText(text)

        // Save to persistence
        Task {
            do {
                try await persistence.updateNote(notes[index])
            } catch {
                print("Failed to update note: \(error)")
            }
        }
    }

    /// Updates an existing note's color
    func updateNoteColor(_ note: StickyNote, color: NoteColor) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        notes[index].color = color
        noteEntities[note.id]?.updateColor(color)

        // Save to persistence
        Task {
            do {
                try await persistence.updateNote(notes[index])
            } catch {
                print("Failed to update note color: \(error)")
            }
        }
    }

    /// Deletes a note
    func deleteNote(_ note: StickyNote) {
        notes.removeAll { $0.id == note.id }

        if let entity = noteEntities[note.id] {
            arManager.removeEntity(entity)
            noteEntities.removeValue(forKey: note.id)
        }

        selectedNote = nil

        // Delete from persistence
        Task {
            do {
                try await persistence.deleteNote(id: note.id)
            } catch {
                print("Failed to delete note: \(error)")
            }
        }
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

// MARK: - Notification Names

extension Notification.Name {
    static let saveWorldMap = Notification.Name("saveWorldMap")
}
