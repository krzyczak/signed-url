require 'openssl'
require 'uri'
require 'cgi'
require 'base64'

require 'pry'

module SignedUrl
  class << self
    attr_accessor :encoder

    def configure
      self.encoder ||= UrlEncoder.new
      yield(encoder)
    end

    def generate(path:, expires:)
      encoder.encode(path: path, expires: expires)
    end

    def validate(key_id:, secret:, path:, host:, expires:, request_url:)
      validating_encoder = UrlEncoder.new
      validating_encoder.host = host
      validating_encoder.key_id = key_id
      validating_encoder.secret = secret
      url_matched = (request_url == validating_encoder.encode(path: path, expires: expires))
      time_in_the_future = Time.at(expires.to_i).utc > Time.now.utc
      url_matched && time_in_the_future
    end
  end

  class UrlEncoder
    attr_accessor :host, :key_id, :secret

    def encode(path:, expires:)
      expires = expires.to_i
      digest = OpenSSL::Digest.new('sha256')
      hmac = OpenSSL::HMAC.digest(digest, @secret, "GET\n\n\n#{expires}\n/#{path}")
      signature = CGI.escape(URI.escape(Base64.encode64(hmac).strip))
      generate_url(host: @host, path: path, access_key_id: @key_id, expires: expires, signature: signature)
    end

    private

    def generate_url(host:, path:, access_key_id:, expires:, signature:)
      "#{host}#{path}?access_key_id=#{access_key_id}&expires=#{expires}&signature=#{signature}"
    end
  end
end
