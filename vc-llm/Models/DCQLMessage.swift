//
//  DCQLMessage.swift
//  vc-llm
//
//  Created by Assistant on 2025/10/19.
//

import Foundation

// Mode enum for different app states
enum AppMode {
    case chat
    case dcql
    case presentation
}

// Message type extended for DCQL
struct DCQLMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let dcqlResponse: DCQLResponse?
    let timestamp = Date()

    init(text: String, isUser: Bool, dcqlResponse: DCQLResponse? = nil) {
        self.text = text
        self.isUser = isUser
        self.dcqlResponse = dcqlResponse
    }

    static func == (lhs: DCQLMessage, rhs: DCQLMessage) -> Bool {
        lhs.id == rhs.id
    }
}
