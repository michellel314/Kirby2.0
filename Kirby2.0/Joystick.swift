//
//  Joystick.swift
//  Kirby2.0
//
//  Created by Michelle Lee on 5/31/26.
//

import SwiftUI

struct Joystick: View {
    @Binding var movement: CGSize
    @State private var knobOffset = CGSize.zero
    var body: some View {
        ZStack{
            
            //base circle
            Circle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 100, height: 100)
            
            //thumbstick
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .offset(knobOffset)
                .gesture(
                    DragGesture()
                        .onChanged{ value in
                            let radius: CGFloat = 35
                            
                            let dx = value.translation.width
                            let dy = value.translation.height
                            
                            let distance = sqrt(dx*dx + dy*dy)
                            
                            if distance < radius {
                                knobOffset = value.translation
                            } else {
                                let angle = atan2(dy, dx)
                                
                                knobOffset = CGSize(
                                    width: cos(angle)*radius,
                                    height: sin(angle)*radius
                                )
                                
                            }
                            movement = knobOffset
                        }
                        .onEnded{ _ in
                            withAnimation {
                                knobOffset = .zero
                            }
                            
                            movement = .zero
                            
                        }
                )
        }
    }
}
