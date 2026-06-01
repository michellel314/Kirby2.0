//
//  JumpButton.swift
//  Kirby2.0
//
//  Created by Student on 6/1/26.
//

import SwiftUI

struct JumpButton: View {
    let onJump:() -> Void
    var body: some View {
        Button(action: {
            onJump()
        }) {
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 70, height: 70)
                .overlay(
                    Text("JUMP")
                        .font(.caption)
                        .foregroundColor(.black)
                )
                .shadow(radius: 3)
        }
    }
}
