//
//  ContentView.swift
//  spatial-notes
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ARViewModel()
    @State private var isShowingNotesList = false

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                // Top bar with debug toggle and status
                HStack(alignment: .top) {
                    // Debug toggle (top left)
                    DebugToggleButton(isEnabled: viewModel.arManager.debugModeEnabled) {
                        viewModel.toggleDebugMode()
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Status banner (top center)
                    VStack {
                        if viewModel.arManager.isRelocalizing {
                            StatusBanner(message: "Finding your space - look around...", type: .info)
                        } else if let error = viewModel.arManager.errorMessage {
                            StatusBanner(message: error, type: .warning)
                        } else if !viewModel.arManager.surfaceDetected {
                            StatusBanner(message: "Look around to detect surfaces", type: .info)
                        }
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Empty spacer to balance layout
                    Color.clear.frame(width: 32, height: 32)
                        .padding(.top, 60)
                }
                .padding(.horizontal, 16)

                // Debug overlay (below toggle when enabled)
                if viewModel.arManager.debugModeEnabled {
                    HStack {
                        DebugOverlayView(
                            arManager: viewModel.arManager,
                            noteCount: viewModel.notes.count
                        )
                        .padding(.leading, 16)
                        .padding(.top, 8)

                        Spacer()
                    }
                }

                Spacer()

                // Instructions based on state
                if viewModel.notes.isEmpty && viewModel.arManager.surfaceDetected && !viewModel.arManager.isRelocalizing {
                    if viewModel.hasActiveSpace && !viewModel.notesLoaded {
                        InstructionBubble(text: "Loading your notes...")
                            .padding(.bottom, 100)
                    } else {
                        InstructionBubble(text: "Tap anywhere to place a note")
                            .padding(.bottom, 100)
                    }
                }

                // Bottom toolbar
                ToolbarView(noteCount: viewModel.notes.count) {
                    isShowingNotesList = true
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $viewModel.isShowingNoteInput) {
            NoteInputSheet(
                onSave: { text, color in
                    viewModel.createNote(text: text, color: color)
                },
                onCancel: {
                    viewModel.cancelNoteCreation()
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $viewModel.selectedNote) { note in
            NoteDetailView(
                note: note,
                onUpdate: { text in
                    viewModel.updateNote(note, text: text)
                },
                onUpdateColor: { color in
                    viewModel.updateNoteColor(note, color: color)
                },
                onDelete: {
                    viewModel.deleteNote(note)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingNotesList) {
            NotesListSheet(
                notes: viewModel.notes,
                onDelete: { note in
                    viewModel.deleteNote(note)
                },
                onSelect: { note in
                    viewModel.selectedNote = note
                },
                onNewSpace: {
                    viewModel.startNewSpace()
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Supporting Views

struct StatusBanner: View {
    let message: String
    let type: BannerType

    enum BannerType {
        case info, warning

        var backgroundColor: Color {
            switch self {
            case .info: return Color.blue.opacity(0.8)
            case .warning: return Color.orange.opacity(0.8)
            }
        }
    }

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(type.backgroundColor)
            .cornerRadius(20)
    }
}

struct InstructionBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.6))
            .cornerRadius(25)
    }
}

#Preview {
    ContentView()
}
