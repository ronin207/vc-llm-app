//
//  DCQLMessage.swift
//  vc-llm
//
//  Created by Assistant on 2025/10/19.
//

import Foundation
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
