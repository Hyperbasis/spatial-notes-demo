//
//  NoteDetailView.swift
//  spatial-notes
//

import SwiftUI

struct NoteDetailView: View {
    let note: StickyNote
    let onUpdate: (String) -> Void
    let onUpdateColor: (NoteColor) -> Void
    let onDelete: () -> Void

    @State private var editedText: String = ""
    @State private var selectedColor: NoteColor = .yellow
    @State private var showDeleteConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Text editor
                TextField("Note text", text: $editedText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .padding(.horizontal)

                // Color picker
                HStack(spacing: 16) {
                    ForEach(NoteColor.allCases, id: \.self) { color in
                        ColorButton(
                            color: color,
                            isSelected: selectedColor == color,
                            action: {
                                selectedColor = color
                                onUpdateColor(color)
                            }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Note")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 20)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onUpdate(editedText)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            editedText = note.text
            selectedColor = note.color
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
