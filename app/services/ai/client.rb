module Ai
  # Builds an Anthropic SDK client from the owner's saved key and turns SDK errors into
  # `Ai::Error`s with a stable `code` and a message that can be shown in the UI.
  # Messages never include the key.
  class Client
    class Error < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end

      def retryable?
        %w[rate_limited unavailable timeout].include?(code)
      end
    end

    TIMEOUT_SECONDS = 60
    MAX_RETRIES = 2

    def self.for(setting = AppSetting.current)
      raise Error.new("not_configured", "No Claude API key is configured.") unless setting.claude_configured?

      new(api_key: setting.claude_api_key, model: setting.effective_claude_model)
    end

    attr_reader :model

    def initialize(api_key:, model:, max_retries: MAX_RETRIES)
      @model = model
      @sdk = Anthropic::Client.new(api_key: api_key, timeout: TIMEOUT_SECONDS, max_retries: max_retries)
    end

    # Cheapest authenticated call: lists one model. Raises Ai::Client::Error on failure.
    def verify!
      translate_errors { @sdk.models.list(limit: 1) }
      true
    end

    def messages
      @sdk.messages
    end

    def translate_errors
      yield
    rescue Anthropic::Errors::AuthenticationError, Anthropic::Errors::PermissionDeniedError
      raise Error.new("invalid_key", "Your Claude API key was rejected. Update it in Settings.")
    rescue Anthropic::Errors::RateLimitError
      raise Error.new("rate_limited", "Claude's rate limit was reached. Suggestions will be retried shortly.")
    rescue Anthropic::Errors::PaymentRequiredError
      raise Error.new("billing", "Your Anthropic account has no credit left. Add credit in the Claude Console.")
    rescue Anthropic::Errors::APITimeoutError, Anthropic::Errors::RequestTimeoutError
      raise Error.new("timeout", "Claude took too long to answer. Try again later.")
    rescue Anthropic::Errors::APIConnectionError
      raise Error.new("unavailable", "Couldn't reach the Claude API. Check the connection and try again.")
    rescue Anthropic::Errors::InternalServerError
      raise Error.new("unavailable", "The Claude API is having problems. Suggestions will be retried shortly.")
    rescue Anthropic::Errors::BadRequestError, Anthropic::Errors::NotFoundError => e
      raise Error.new("bad_request", "Claude rejected the request (#{e.class.name.demodulize}). Check the model name in Settings.")
    rescue Anthropic::Errors::APIStatusError => e
      raise Error.new("api_error", "The Claude API returned an error (HTTP #{e.status}).")
    end
  end
end
