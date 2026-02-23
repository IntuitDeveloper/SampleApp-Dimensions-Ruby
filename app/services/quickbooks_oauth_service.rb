require "base64"
require "securerandom"
require "faraday"

class QuickbooksOauthService
  OAUTH_BASE = "https://appcenter.intuit.com/connect/oauth2"
  TOKEN_URL = "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"

  def initialize(config: QuickbooksConfig.new)
    @config = config
  end

  def authorization_url
    @config.validate_config!
    state = generate_state
    params = {
      client_id: @config.client_id,
      scope: "com.intuit.quickbooks.accounting app-foundations.custom-dimensions.read",
      redirect_uri: @config.get_dynamic_redirect_uri,
      response_type: "code",
      access_type: "offline",
      state: state
    }
    "#{OAUTH_BASE}?#{Rack::Utils.build_query(params)}"
  end

  def exchange_code_for_token(auth_code:, realm_id:)
    raise ArgumentError, "Authorization code is required" if auth_code.to_s.strip.empty?
    raise ArgumentError, "Realm ID is required" if realm_id.to_s.strip.empty?
    @config.validate_config!

    conn = Faraday.new(url: TOKEN_URL)
    resp = conn.post do |req|
      req.headers["Authorization"] = "Basic #{basic_auth_header}"
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.headers["Accept"] = "application/json"
      req.body = {
        grant_type: "authorization_code",
        code: auth_code,
        redirect_uri: @config.get_dynamic_redirect_uri
      }
    end

    if resp.status == 200
      data = JSON.parse(resp.body)
      {
        "access_token" => data["access_token"],
        "refresh_token" => data["refresh_token"],
        "expires_in" => data["expires_in"],
        "realm_id" => realm_id
      }
    else
      msg = begin
        JSON.parse(resp.body).fetch("error_description")
      rescue
        resp.body
      end
      raise "OAuth token exchange failed: #{msg}"
    end
  end

  def refresh_token(refresh_token:)
    raise ArgumentError, "Refresh token is required" if refresh_token.to_s.strip.empty?
    @config.validate_config!

    conn = Faraday.new(url: TOKEN_URL)
    resp = conn.post do |req|
      req.headers["Authorization"] = "Basic #{basic_auth_header}"
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.headers["Accept"] = "application/json"
      req.body = {
        grant_type: "refresh_token",
        refresh_token: refresh_token
      }
    end

    if resp.status == 200
      data = JSON.parse(resp.body)
      {
        "access_token" => data["access_token"],
        "refresh_token" => data["refresh_token"] || refresh_token,
        "expires_in" => data["expires_in"]
      }
    else
      msg = begin
        JSON.parse(resp.body).fetch("error_description")
      rescue
        resp.body
      end
      raise "Token refresh failed: #{msg}"
    end
  end

  private

  def basic_auth_header
    Base64.strict_encode64("#{@config.client_id}:#{@config.client_secret}")
  end

  def generate_state
    SecureRandom.urlsafe_base64(32)
  end
end