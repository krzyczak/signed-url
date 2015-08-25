require 'test_helper'
require 'signed_url'
require 'pry'

class SignedUrlTest < Minitest::Test
  def setup
    SignedUrl.configure do |config|
      config.secret = 'secret'
      config.key_id = 'key_id'
      config.host = 'http://superhost:3000'
    end
  end

  def test_is_configurable
    assert_equal 'secret', SignedUrl.encoder.secret
    assert_equal 'key_id', SignedUrl.encoder.key_id
    assert_equal 'http://superhost:3000', SignedUrl.encoder.host
  end

  def test_generate
    expires = Time.at(1_439_888_470 + 3600).utc
    encoded = SignedUrl.generate(path: '/super/path/1', expires: expires)
    params = Hash[encoded.split('?').last.split('&').map { |p| p.split('=') }]

    assert_equal 'key_id', params['access_key_id']
    assert_equal expires.to_i.to_s, params['expires']
    assert_equal '467lTpWT1ODYO6zHI76oVB1QEtLdxcUoSDycXLzgdJY%3D', params['signature']
    assert_equal 'http://superhost:3000/super/path/1', encoded.split('?').first
  end

  def test_validate_succeeds
    time = Time.at(1_439_888_470).utc # "2015-08-18 09:01:10 UTC"

    Timecop.freeze(time - 3600) do
      validation_result = SignedUrl.validate(
        key_id: 'key_id',
        secret: 'secret',
        path: '/path/to/resource/1',
        host: 'http://superhost:3000',
        expires: (time + 3600).to_i,
        request_url: 'http://superhost:3000/path/to/resource/1?access_key_id=key_id&expires=1439892070&signature=s1cd1QD23Thg8QUhS94TYguz29dA67KS8eGKRH%2BpGbw%3D'
      )

      assert_equal true, validation_result
    end
  end

  def test_validate_fails_if_time_is_in_the_past_or_present
    time = Time.at(1_439_888_470).utc # "2015-08-18 09:01:10 UTC"

    Timecop.freeze(time + 3600) do
      validation_result = SignedUrl.validate(
        key_id: 'key_id',
        secret: 'secret',
        path: '/path/to/resource/1',
        host: 'http://superhost:3000',
        expires: (time + 3600).to_i,
        request_url: 'http://superhost:3000/path/to/resource/1?access_key_id=key_id&expires=1439892070&signature=s1cd1QD23Thg8QUhS94TYguz29dA67KS8eGKRH%2BpGbw%3D'
      )

      assert_equal false, validation_result
    end
  end

  def test_validate_fails_if_time_is_manipulated
    time = Time.at(1_439_888_470).utc # "2015-08-18 09:01:10 UTC"

    Timecop.freeze(time + 3600) do
      validation_result = SignedUrl.validate(
        key_id: 'key_id',
        secret: 'secret',
        path: '/path/to/resource/1',
        host: 'http://superhost:3000',
        expires: (time + 3600).to_i + 3600,
        request_url: 'http://superhost:3000/path/to/resource/1?access_key_id=key_id&expires=1439892070&signature=s1cd1QD23Thg8QUhS94TYguz29dA67KS8eGKRH%2BpGbw%3D'
      )

      assert_equal false, validation_result
    end
  end

  def test_validate_fails_if_secret_is_invalid
    time = Time.at(1_439_888_470).utc # "2015-08-18 09:01:10 UTC"

    Timecop.freeze(time + 3600) do
      validation_result = SignedUrl.validate(
        key_id: 'key_id',
        secret: 'ibvalid_secret',
        path: '/path/to/resource/1',
        host: 'http://superhost:3000',
        expires: (time + 3600).to_i,
        request_url: 'http://superhost:3000/path/to/resource/1?access_key_id=key_id&expires=1439892070&signature=s1cd1QD23Thg8QUhS94TYguz29dA67KS8eGKRH%2BpGbw%3D'
      )

      assert_equal false, validation_result
    end
  end

  def test_validate_fails_if_key_id_is_invalid
    time = Time.at(1_439_888_470).utc # "2015-08-18 09:01:10 UTC"

    Timecop.freeze(time + 3600) do
      validation_result = SignedUrl.validate(
        key_id: 'invalid_key_id',
        secret: 'secret',
        path: '/path/to/resource/1',
        host: 'http://superhost:3000',
        expires: (time + 3600).to_i,
        request_url: 'http://superhost:3000/path/to/resource/1?access_key_id=key_id&expires=1439892070&signature=s1cd1QD23Thg8QUhS94TYguz29dA67KS8eGKRH%2BpGbw%3D'
      )

      assert_equal false, validation_result
    end
  end
end
