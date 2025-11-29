//
//  NotesListSheet.swift
//  spatial-notes
//

import SwiftUI

struct NotesListSheet: View {
    let notes: [StickyNote]
    let onDelete: (StickyNote) -> Void
    let onSelect: (StickyNote) -> Void
    let onNewSpace: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showNewSpaceConfirmation = false

    var body: some View {
        NavigationView {
            Group {
                if notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Notes Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap anywhere in AR to place a note")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notes) { note in
                            NoteRowView(note: note)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onSelect(note)
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                onDelete(notes[index])
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showNewSpaceConfirmation = true
                    } label: {
                        Label("New Space", systemImage: "plus.square")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Start a New Space?",
                isPresented: $showNewSpaceConfirmation,
                titleVisibility: .visible
            ) {
                Button("New Space", role: .destructive) {
                    onNewSpace()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all current notes and start fresh in a new location.")
            }
        }
    }
}

struct NoteRowView: View {
    let note: StickyNote

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(note.color.uiColor))
                .frame(width: 8, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                // Note text (truncated)
                Text(note.text)
                    .font(.body)
                    .lineLimit(2)

                // Created date
                Text(note.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
