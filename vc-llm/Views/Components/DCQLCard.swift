//
//  DCQLCard.swift
//  vc-llm
//
//  Created by Assistant on 2025/10/19.
//

import SwiftUI

struct DCQLDetailsView: View {
    let dcqlResponse: DCQLResponse
    let onPresentTapped: () -> Void
    @State private var showingJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected Credentials:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))

                ForEach(dcqlResponse.selectedVCs) { vc in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text(vc.type.last ?? "Unknown")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    showingJSON.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingJSON ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                        Text(showingJSON ? "Hide DCQL" : "View DCQL")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.1))
                    )
                }

                Button {
                    onPresentTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 12))
                        Text("Present")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cyan.opacity(0.3))
                    )
                }
            }
            .foregroundColor(.primary)

            // DCQL JSON (collapsible)
            if showingJSON {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Text(dcqlResponse.dcqlString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.7))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .frame(maxHeight: 200)
            }
        }
    }
}
