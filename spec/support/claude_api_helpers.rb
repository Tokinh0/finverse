# Stubs for the Claude API. Real HTTP is blocked by WebMock, so specs never reach Anthropic.
module ClaudeApiHelpers
  CLAUDE_API = "https://api.anthropic.com".freeze

  def stub_claude_models(status: 200, body: { data: [], has_more: false, first_id: nil, last_id: nil })
    stub_request(:get, %r{\A#{CLAUDE_API}/v1/models})
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  # Stubs POST /v1/messages with a text answer holding `answer` as JSON (or a raw string).
  # Returns the WebMock stub so specs can inspect the request.
  def stub_claude_message(answer, stop_reason: "end_turn", input_tokens: 120, output_tokens: 40)
    text = answer.is_a?(String) ? answer : answer.to_json
    body = {
      id: "msg_test", type: "message", role: "assistant", model: "claude-haiku-5-5",
      content: [ { type: "text", text: text } ], stop_reason: stop_reason, stop_sequence: nil,
      usage: { input_tokens: input_tokens, output_tokens: output_tokens }
    }
    stub_request(:post, "#{CLAUDE_API}/v1/messages")
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  # The JSON body of the last request sent to /v1/messages.
  def claude_request_body
    request = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.reverse
                                      .find { _1.method == :post && _1.uri.path == "/v1/messages" }
    JSON.parse(request.body)
  end

  def claude_error_body(type, message = "error")
    { type: "error", error: { type: type, message: message } }
  end
end

RSpec.configure { |config| config.include ClaudeApiHelpers }
