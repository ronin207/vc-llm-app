//
//  VCListView.swift
//  vc-llm
//
//  Created by Assistant on 2025/10/19.
//

import SwiftUI

struct VCListView: View {
    @State private var credentials: [VerifiableCredential] = []
    @State private var selectedCredential: VerifiableCredential?
    @State private var showingDetail = false

    // Gradient colors for cards
    let gradients: [LinearGradient] = [
        LinearGradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.green.opacity(0.6), Color.teal.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.orange.opacity(0.6), Color.red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.pink.opacity(0.6), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(credentials.enumerated()), id: \.element.id) { index, credential in
                            VCCardView(
                                credential: credential,
                                gradient: gradients[index % gradients.count]
                            )
                            .onTapGesture {
                                selectedCredential = credential
                                showingDetail = true
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Verifiable Credentials")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadCredentials()
            }
            .sheet(isPresented: $showingDetail) {
                if let credential = selectedCredential {
                    VCDetailView(credential: credential)
                }
            }
        }
    }

    private func loadCredentials() {
        guard let url = Bundle.main.url(forResource: "vc_pool", withExtension: "json") else {
            print("Could not find vc_pool.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            credentials = try decoder.decode([VerifiableCredential].self, from: data)
            print("Loaded \(credentials.count) credentials")
        } catch {
            print("Error loading credentials: \(error)")
        }
    }
}

struct VCCardView: View {
    let credential: VerifiableCredential
    let gradient: LinearGradient

    var credentialType: String {
        credential.type.count > 1 ? credential.type[1] : credential.type[0]
    }

    var issuerName: String {
        credential.issuer.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type badge
            HStack {
                Text(credentialType)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Issuer info
            VStack(alignment: .leading, spacing: 4) {
                Text("ISSUED BY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Text(issuerName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(gradient)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

struct VCDetailView: View {
    @Environment(\.dismiss) var dismiss
    let credential: VerifiableCredential

    var credentialType: String {
        credential.type.count > 1 ? credential.type[1] : credential.type[0]
    }

    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(credential),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(credentialType)
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        Text("Issued by: \(credential.issuer.name)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Credential Subject
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credential Subject")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(Array(credential.credentialSubject.keys.sorted()), id: \.self) { key in
                                if let value = credential.credentialSubject[key] {
                                    HStack {
                                        Text(key)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Text(formatValue(value))
                                            .font(.system(size: 14, weight: .regular))
                                            .multilineTextAlignment(.trailing)
                                    }
                                    .padding(.horizontal)

                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }

                    // Full JSON
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full JSON")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .padding(.horizontal)

                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            Text(jsonString)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary.opacity(0.8))
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.primary.opacity(0.05))
                                )
                        }
                        .frame(maxHeight: 300)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Credential Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatValue(_ value: Any) -> String {
        if let str = value as? String {
            return str
        } else if let dict = value as? [String: Any] {
            return "{\(dict.count) items}"
        } else if let array = value as? [Any] {
            return "[\(array.count) items]"
        }
        return "\(value)"
    }
}

// Decodable struct for VerifiableCredential
struct VerifiableCredential: Codable, Identifiable {
    let id: String
    let type: [String]
    let issuer: Issuer
    let validFrom: String?
    let validUntil: String?
    let credentialSubject: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case issuer
        case validFrom
        case validUntil
        case credentialSubject
    }
}

struct Issuer: Codable {
    let id: String
    let name: String
}

// Helper to decode Any type in JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}

#Preview {
    VCListView()
}
