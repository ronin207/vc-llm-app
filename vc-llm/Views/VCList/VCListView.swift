import SwiftUI

struct VCListView: View {
    @State private var credentials: [VerifiableCredential] = []
    @State private var selectedCredential: VerifiableCredential?
    @State private var searchText = ""

    var filteredCredentials: [VerifiableCredential] {
        if searchText.isEmpty {
            return credentials
        }
        let lowercasedSearch = searchText.lowercased()
        return credentials.filter { credential in
            let credentialType = credential.primaryType
            return credentialType.lowercased().contains(lowercasedSearch)
        }
    }

    let gradients: [LinearGradient] = [
        LinearGradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.green.opacity(0.6), Color.teal.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.orange.opacity(0.6), Color.red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.pink.opacity(0.6), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredCredentials) { credential in
                        VCCardView(
                            credential: credential,
                            gradient: gradient(for: credential)
                        )
                        .onTapGesture {
                            selectedCredential = credential
                        }
                    }

                    if filteredCredentials.isEmpty && !credentials.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("No credentials found")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)

                            Text("Try a different search term")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
        }
        .searchable(text: $searchText, prompt: "Search credentials")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: FormView()) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Credentials")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if credentials.isEmpty {
                    loadCredentials()
                }
            }
            .sheet(item: $selectedCredential) { credential in
                VCDetailView(credential: credential)
            }
    }

    private func gradient(for credential: VerifiableCredential) -> LinearGradient {
        let hash = UInt(bitPattern: credential.id.hashValue)
        let index = Int(hash % UInt(gradients.count))
        return gradients[index]
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
        credential.primaryType
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
    @State private var jsonString: String = ""

    var credentialType: String {
        credential.primaryType
    }

    private func generateJSONString() -> String {
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

                                        Text(value.stringValue)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if jsonString.isEmpty {
                    jsonString = generateJSONString()
                }
            }
        }
    }

}

struct VerifiableCredential: Codable, Identifiable {
    let id: String
    let type: [String]
    let issuer: Issuer
    let credentialSubject: [String: JSONValue]

    var primaryType: String {
        if type.count > 1 {
            return type[1]
        }
        return type.first ?? "Unknown Credential"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case issuer
        case credentialSubject
    }
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .object(let dict):
            // Convert object to JSON string for display
            if let data = try? JSONEncoder().encode(dict),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return "{...}"
        case .array(let arr):
            return "[\(arr.count) items]"
        case .null:
            return "null"
        }
    }
}

struct Issuer: Codable {
    let id: String
    let name: String
}

#Preview {
    VCListView()
}
