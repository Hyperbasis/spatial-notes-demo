//
//  ToolbarView.swift
//  spatial-notes
//

import SwiftUI

struct ToolbarView: View {
    let noteCount: Int

    var body: some View {
        HStack {
            // Note count indicator
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                Text("\(noteCount)")
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
