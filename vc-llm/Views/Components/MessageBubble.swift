//
//  MessageBubble.swift
//  vc-llm
//
//  Created by Assistant on 2025/10/19.
//

import SwiftUI

// Message bubble component
struct MessageBubble: View {
    @Environment(\.colorScheme) var colorScheme
    let message: DCQLMessage
    let onPresentTapped: () -> Void

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.95))

                // Show DCQL details if available
                if let dcql = message.dcqlResponse {
                    DCQLDetailsView(dcqlResponse: dcql, onPresentTapped: onPresentTapped)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bubbleBackground)
            .frame(maxWidth: 320, alignment: message.isUser ? .trailing : .leading)

            Text(formattedTime(from: message.timestamp))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(message.isUser ?
                  LinearGradient(
                    colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ) :
                  LinearGradient(
                    colors: colorScheme == .dark ?
                        [Color.white.opacity(0.1), Color.white.opacity(0.05)] :
                        [Color.black.opacity(0.05), Color.black.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        message.isUser ?
                            Color.cyan.opacity(0.3) :
                            Color.primary.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
    }

    func formattedTime(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        return dateFormatter.string(from: date)
    }
}
