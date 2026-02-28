import SwiftUI

struct AIRefineSettingsView: View {
    @AppStorage("ollamaEnabled") private var ollamaEnabled: Bool = false
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel: String = "gemma3:4b"
    /// Empty string means "use the built-in default prompt".
    @AppStorage("ollamaPrompt") private var ollamaPrompt: String = ""

    @State private var testStatus: TestStatus = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Enable toggle
                SettingsSection(title: "AI Text Refinement") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable AI Refinement", isOn: $ollamaEnabled)

                        Text("After transcription, the text is sent to a local Ollama model which removes filler words, false starts, and verbal noise before pasting the result.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Ollama config
                SettingsSection(title: "Ollama Configuration") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server URL")
                                .fontWeight(.medium)
                            TextField("http://localhost:11434", text: $ollamaURL)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!ollamaEnabled)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Name")
                                .fontWeight(.medium)
                            TextField("gemma3:4b", text: $ollamaModel)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!ollamaEnabled)
                            Text("The model must already be pulled in Ollama (e.g. ollama pull gemma3:4b)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        // Connection test
                        HStack(spacing: 10) {
                            Button("Test Connection") {
                                testConnection()
                            }
                            .disabled(!ollamaEnabled || ollamaURL.isEmpty || ollamaModel.isEmpty)

                            testStatusLabel
                        }
                    }
                }
                .opacity(ollamaEnabled ? 1.0 : 0.5)

                // Prompt customisation
                SettingsSection(title: "Refinement Prompt") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The prompt is prepended to your transcription before it is sent to the model. Leave empty to use the built-in default.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $ollamaPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if ollamaPrompt.isEmpty {
                                    Text(OllamaRefiner.defaultPrompt)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                            .disabled(!ollamaEnabled)

                        if !ollamaPrompt.isEmpty {
                            Button("Reset to Default") {
                                ollamaPrompt = ""
                            }
                            .font(.caption)
                        }
                    }
                }
                .opacity(ollamaEnabled ? 1.0 : 0.5)

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var testStatusLabel: some View {
        switch testStatus {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6)
                Text("Testing…").font(.caption).foregroundStyle(.secondary)
            }
        case .success(let msg):
            Label(msg, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func testConnection() {
        testStatus = .testing
        Task {
            do {
                _ = try await OllamaRefiner.refine(
                    text: "hello world",
                    baseURL: ollamaURL,
                    model: ollamaModel
                )
                await MainActor.run {
                    testStatus = .success("Connected — got response")
                }
            } catch {
                await MainActor.run {
                    testStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}

private enum TestStatus {
    case idle
    case testing
    case success(String)
    case failure(String)
}
