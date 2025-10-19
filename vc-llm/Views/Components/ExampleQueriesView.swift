//
//  ExampleQueriesView.swift
//  vc-llm
//
//  Created by Assistant on 2025/10/19.
//

import SwiftUI

struct ExampleQueriesView: View {
    let queries: [String]
    let onQueryTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try these examples:")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.6))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(queries, id: \.self) { query in
                        Button {
                            onQueryTapped(query)
                        } label: {
                            Text(query)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.cyan.opacity(0.15))
                                )
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
    }
}
