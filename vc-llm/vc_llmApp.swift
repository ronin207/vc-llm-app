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
            // Use the new DCQL-enabled ContentView
            ContentViewDCQL()
            
            // Alternative views for testing:
            // ContentView()  // Original chat-only view
            // ModelTestView()  // Model testing view
        }
    }
}
