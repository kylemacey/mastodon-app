# frozen_string_literal: true

module Account::ProfileMusic::Provider
  Error = Class.new(StandardError)

  MAX_TEXT_LENGTH = 140

  class << self
    def sanitize_text(value)
      value.to_s
        .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '')
        .gsub(/\u00c2(?=[[:space:][:punct:]]|\z)/, '')
        .squish[0, MAX_TEXT_LENGTH]
    end

    def valid_https_url?(value, allowed_hosts: nil)
      return if value.blank?

      uri = Addressable::URI.parse(value)

      return unless allowed_host?(uri.host, allowed_hosts)

      uri.scheme == 'https' && uri.host.present? ? uri.to_s : nil
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def allowed_host?(host, allowed_hosts)
      return true if allowed_hosts.blank?

      allowed_hosts.any? do |allowed_host|
        host == allowed_host || allowed_host.start_with?('.') && host&.end_with?(allowed_host)
      end
    end
  end
end
