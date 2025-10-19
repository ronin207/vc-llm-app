//
//  vc_llmApp.swift
//  vc-llm
//
//  Created by Takumi Otsuka on 2025/07/23.
//

import SwiftUI

@main
struct vc_llmApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentViewDCQL()
                    .tabItem {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    }

                FormView()
                    .tabItem {
                        Label("Form", systemImage: "square.and.pencil")
                    }

                VCListView()
                    .tabItem {
                        Label("Credentials", systemImage: "doc.text.fill")
                    }
            }
        }
    }
}
