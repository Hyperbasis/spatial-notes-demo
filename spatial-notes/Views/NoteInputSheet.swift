//
//  NoteInputSheet.swift
//  spatial-notes
//

import SwiftUI

struct NoteInputSheet: View {
    @State private var text: String = ""
    @State private var selectedColor: NoteColor = .yellow

    let onSave: (String, NoteColor) -> Void
    let onCancel: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Text input
                TextField("What do you want to remember?", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal)

                // Color picker
                HStack(spacing: 16) {
                    ForEach(NoteColor.allCases, id: \.self) { color in
                        ColorButton(
                            color: color,
                            isSelected: selectedColor == color,
                            action: { selectedColor = color }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text, selectedColor)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

struct ColorButton: View {
    let color: NoteColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color.uiColor))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                )
                .shadow(radius: 2)
        }
    }
}
