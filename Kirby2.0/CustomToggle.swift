//
//  CustomToggle.swift
//  Kirby2.0
//
//  Created by Michelle Lee on 5/31/26.
//

import SwiftUI

struct CustomToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)){
                isOn.toggle()
            }
        }) {
            ZStack{
                //Background Track
                RoundedRectangle(cornerRadius: 20)
                    .fill(isOn ? Color.green : Color.gray.opacity(0.6))
                
                //Sliding Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                    .shadow(radius: 2)
                    .offset(x: isOn ? 14.5 : -14.5)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

