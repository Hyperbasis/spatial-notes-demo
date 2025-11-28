//
//  PersistenceManager.swift
//  spatial-notes
//

import Foundation
import Hyperbasis
import ARKit

/// Manages persistence of spaces and notes using Hyperbasis SDK
@MainActor
class PersistenceManager: ObservableObject {

    // MARK: - Properties

    /// The Hyperbasis storage engine
    private let storage: HBStorage

    /// Current space (room) being used
    @Published private(set) var currentSpace: HBSpace?

    /// Whether we're currently saving
    @Published private(set) var isSaving: Bool = false

    /// Whether we're currently loading
    @Published private(set) var isLoading: Bool = false

    /// Last error that occurred
    @Published var lastError: Error?

    // MARK: - Initialization

    init() {
        // Use local-only storage for now
        self.storage = HBStorage(config: .default)
    }

    // MARK: - Space Operations

    /// Creates a new space from the current AR session
    func createSpace(name: String?, worldMap: ARWorldMap) async throws -> HBSpace {
        let space = try HBSpace(name: name, worldMap: worldMap)
        try await storage.save(space)
        self.currentSpace = space
        return space
    }

    /// Updates the current space with a new world map
    func updateSpace(worldMap: ARWorldMap) async throws {
        guard var space = currentSpace else {
            throw PersistenceError.noActiveSpace
        }

        try space.update(worldMap: worldMap)
        try await storage.save(space)
        self.currentSpace = space
    }

    /// Loads the most recent space
    func loadMostRecentSpace() async throws -> HBSpace? {
        isLoading = true
        defer { isLoading = false }

        let spaces = try await storage.loadAllSpaces()

        // Get most recently updated space
        let mostRecent = spaces.max(by: { $0.updatedAt < $1.updatedAt })
        self.currentSpace = mostRecent
        return mostRecent
    }

    /// Loads a specific space by ID
    func loadSpace(id: UUID) async throws -> HBSpace? {
        isLoading = true
        defer { isLoading = false }

        let space = try await storage.loadSpace(id: id)
        self.currentSpace = space
        return space
    }

    // MARK: - Anchor Operations

    /// Saves a sticky note as an anchor
    func saveNote(_ note: StickyNote) async throws {
        guard let space = currentSpace else {
            throw PersistenceError.noActiveSpace
        }

        isSaving = true
        defer { isSaving = false }

        let anchor = HBAnchor(
            id: note.id,
            spaceId: space.id,
            transform: note.simdTransform,
            metadata: note.toMetadata()
        )

        try await storage.save(anchor)
    }

    /// Loads all notes for the current space
    func loadNotes() async throws -> [StickyNote] {
        guard let space = currentSpace else {
            return []
        }

        isLoading = true
        defer { isLoading = false }

        let anchors = try await storage.loadAnchors(spaceId: space.id)
        return anchors.compactMap { StickyNote(from: $0) }
    }

    /// Updates a note
    func updateNote(_ note: StickyNote) async throws {
        guard currentSpace != nil else {
            throw PersistenceError.noActiveSpace
        }

        // Load existing anchor to preserve timestamps
        if var anchor = try await storage.loadAnchor(id: note.id) {
            anchor.update(metadata: note.toMetadata())
            try await storage.save(anchor)
        } else {
            // If anchor doesn't exist, create it
            try await saveNote(note)
        }
    }

    /// Deletes a note
    func deleteNote(id: UUID) async throws {
        try await storage.deleteAnchor(id: id)
    }

    /// Clears all data (for debugging/reset)
    func clearAllData() throws {
        try storage.clearLocalStorage()
        currentSpace = nil
    }
}

// MARK: - Errors

enum PersistenceError: LocalizedError {
    case noActiveSpace
    case worldMapNotAvailable

    var errorDescription: String? {
        switch self {
        case .noActiveSpace:
            return "No active space. Create or load a space first."
        case .worldMapNotAvailable:
            return "AR world map is not available yet. Move around to map more of the environment."
        }
    }
}
