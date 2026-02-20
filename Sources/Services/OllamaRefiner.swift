import Foundation

struct OllamaRefiner {
    /// Sends transcribed text to an Ollama model for cleanup and returns the refined result.
    /// Falls back to the original text on any error.
    static let defaultPrompt = "Clean up this voice transcription. Remove filler words, false starts, repetitions, and verbal noise. Return only the final intended message as plain text with no explanation, preamble, or quotation marks:"

    static func refine(text: String, baseURL: String, model: String, customPrompt: String? = nil) async throws -> String {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let apiURL = URL(string: "\(trimmedURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        let promptBase = customPrompt.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? OllamaRefiner.defaultPrompt
        let prompt = "\(promptBase)\n\n\(text)"

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let refined = json["response"] as? String else {
            throw OllamaError.invalidResponse
        }

        let trimmed = refined.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? text : trimmed
    }
}

enum OllamaError: LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Ollama URL"
        case .requestFailed: return "Ollama request failed — check that the server is running or if the model is available"
        case .invalidResponse: return "Unexpected response from Ollama"
        }
    }
}
