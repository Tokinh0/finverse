module Ai
  # Builds an Anthropic SDK client from the owner's saved key and turns SDK errors into
  # `Ai::Error`s with a stable `code` and a message that can be shown in the UI.
  # Messages never include the key.
  class Client
    # `code` is stable (for the UI and retries); the message comes from config/locales
    # (ai.errors.<key>, key defaulting to the code) in the current language.
    class Error < StandardError
      attr_reader :code

      def initialize(code, key: code, **params)
        @code = code
        super(I18n.t("ai.errors.#{key}", **params))
      end

      def retryable?
        false
      end
    end

    # Rate limits, timeouts and outages: worth trying again later.
    class RetryableError < Error
      def retryable?
        true
      end
    end

    TIMEOUT_SECONDS = 60
    MAX_RETRIES = 2

    def self.for(setting = AppSetting.current)
      raise Error.new("not_configured") unless setting.claude_configured?

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
      raise Error.new("invalid_key")
    rescue Anthropic::Errors::RateLimitError
      raise RetryableError.new("rate_limited")
    rescue Anthropic::Errors::PaymentRequiredError
      raise Error.new("billing")
    rescue Anthropic::Errors::APITimeoutError, Anthropic::Errors::RequestTimeoutError
      raise RetryableError.new("timeout")
    rescue Anthropic::Errors::APIConnectionError
      raise RetryableError.new("unavailable")
    rescue Anthropic::Errors::InternalServerError
      raise RetryableError.new("unavailable", key: "server_error")
    rescue Anthropic::Errors::BadRequestError, Anthropic::Errors::NotFoundError => e
      raise Error.new("bad_request", error: e.class.name.demodulize)
    rescue Anthropic::Errors::APIStatusError => e
      raise Error.new("api_error", status: e.status)
    end
  end
end
