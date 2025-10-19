import SwiftUI

struct PresentationView: View {
    @Environment(\.dismiss) var dismiss
    let dcqlResponse: DCQLResponse
    @State private var qrImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Share Presentation")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.top)

                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                        )
                        .shadow(radius: 10)
                } else {
                    VStack(spacing: 8) {
                        ProgressView("Generating QR Code...")
                        Text("Preparing your presentation data...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 300, height: 300)
                }

                VStack(spacing: 8) {
                    Text("Scan to receive presentation")
                        .font(.system(size: 18, weight: .medium, design: .rounded))

                    Text("This QR code contains your selected credentials")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cyan)
                )
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .task { await generateQRCodeAsync() }
    }

    private func generateQRCodeAsync() async {
        // Filter credentials strictly to those referenced in DCQL if possible
        var selected: [VCEmbeddings.VerifiableCredential] = dcqlResponse.selectedVCs
        if let dcqlCreds = dcqlResponse.dcql["credentials"] as? [[String: Any]] {
            let dcqlTypeSet: Set<String> = Set(dcqlCreds.compactMap { cred in
                if let meta = cred["meta"] as? [String: Any],
                   let typeValues = meta["type_values"] as? [[String]],
                   let types = typeValues.first {
                    return types.last
                }
                return nil
            })
            if !dcqlTypeSet.isEmpty {
                selected = dcqlResponse.selectedVCs.filter { vc in
                    if let t = vc.type.last { return dcqlTypeSet.contains(t) }
                    return false
                }
            }
        }

        let presentationData: [String: Any] = [
            "type": "VerifiablePresentation",
            "credentials": selected.map { vc in
                [
                    "id": vc.id,
                    "type": vc.type,
                    "issuer": ["id": vc.issuer.id, "name": vc.issuer.name],
                    "credentialSubject": vc.credentialSubject.mapValues { $0.value }
                ]
            },
            "dcql": dcqlResponse.dcql,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: presentationData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            await MainActor.run { qrImage = QRCodeGenerator.generate(from: jsonString) }
        } else {
            await MainActor.run { qrImage = QRCodeGenerator.generate(from: "{}") }
        }
    }
}

// Fallback view shown if `currentDCQLResponse` is nil
struct PresentationFallbackView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView("Preparing presentation...")
                Text("Please try again.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Button("Close") { dismiss() }
                    .padding(.top, 4)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}
