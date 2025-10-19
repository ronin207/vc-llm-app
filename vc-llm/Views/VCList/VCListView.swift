import SwiftUI

struct VCListView: View {
    @State private var credentials: [VerifiableCredential] = []
    @State private var selectedCredential: VerifiableCredential?
    @State private var showingDetail = false
    @State private var searchText = ""

    var filteredCredentials: [VerifiableCredential] {
        if searchText.isEmpty {
            return credentials
        }
        return credentials.filter { credential in
            let credentialType = credential.type.count > 1 ? credential.type[1] : credential.type[0]
            let issuerName = credential.issuer.name

            // Search in type, issuer name, and credentialSubject values
            let matchesType = credentialType.localizedCaseInsensitiveContains(searchText)
            let matchesIssuer = issuerName.localizedCaseInsensitiveContains(searchText)
            let matchesSubject = credential.credentialSubject.values.contains { value in
                value.stringValue.localizedCaseInsensitiveContains(searchText)
            }

            return matchesType || matchesIssuer || matchesSubject
        }
    }

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

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search credentials...", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(filteredCredentials.enumerated()), id: \.element.id) { index, credential in
                                VCCardView(
                                    credential: credential,
                                    gradient: gradients[index % gradients.count]
                                )
                                .onTapGesture {
                                    selectedCredential = credential
                                    showingDetail = true
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
                        .padding()
                    }
                }
            }
            .navigationTitle("Credentials")
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

}

// Decodable struct for VerifiableCredential
struct VerifiableCredential: Codable, Identifiable {
    let context: [String]?
    let id: String
    let type: [String]
    let issuer: Issuer
    let validFrom: String?
    let validUntil: String?
    let credentialSubject: [String: JSONValue]
    let proof: Proof?

    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case issuer
        case validFrom
        case validUntil
        case credentialSubject
        case proof
    }
}

// Helper enum to decode any JSON value
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

struct Proof: Codable {
    let type: String
    let cryptosuite: String?
    let created: String?
    let verificationMethod: String?
    let proofPurpose: String?
    let proofValue: String?
}

struct Issuer: Codable {
    let id: String
    let name: String
}

#Preview {
    VCListView()
}
