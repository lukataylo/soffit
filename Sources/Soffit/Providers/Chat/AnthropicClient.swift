import Foundation

struct AnthropicClient {
    let apiKey: String
    let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    let apiVersion = "2023-06-01"

    func stream(messages: [ChatMessage], model: String) async throws -> AsyncThrowingStream<String, Error> {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let apiMessages = messages.filter { $0.role != .system }.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "messages": apiMessages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.badResponse("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            var errText = "HTTP \(http.statusCode)"
            var collected = ""
            for try await line in bytes.lines { collected += line + "\n" ; if collected.count > 2000 { break } }
            errText += ": \(collected)"
            throw AnthropicError.badResponse(errText)
        }

        return AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let jsonText = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                        guard !jsonText.isEmpty, jsonText != "[DONE]" else { continue }
                        if let data = jsonText.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let type = obj["type"] as? String {
                                if type == "content_block_delta",
                                   let delta = obj["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    continuation.yield(text)
                                } else if type == "message_stop" {
                                    continuation.finish(); return
                                } else if type == "error",
                                          let err = obj["error"] as? [String: Any],
                                          let msg = err["message"] as? String {
                                    continuation.finish(throwing: AnthropicError.badResponse(msg))
                                    return
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum AnthropicError: LocalizedError {
    case badResponse(String)
    var errorDescription: String? {
        switch self {
        case .badResponse(let s): return s
        }
    }
}
