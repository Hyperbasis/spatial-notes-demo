//
//  ToolbarView.swift
//  spatial-notes
//

import SwiftUI

struct ToolbarView: View {
    let noteCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                Text("\(noteCount)")
                Image(systemName: "chevron.up")
                    .font(.caption)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
        }
    }
}
