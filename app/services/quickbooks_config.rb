class QuickbooksConfig
  attr_reader :client_id, :client_secret, :redirect_uri, :environment, :base_url, :graphql_url

  def initialize
    @client_id = ENV.fetch("QB_CLIENT_ID", "your-client-id")
    @client_secret = ENV.fetch("QB_CLIENT_SECRET", "your-client-secret")
    @redirect_uri = ENV.fetch("QB_REDIRECT_URI", "your-redirect-uri")
    @environment = ENV.fetch("QB_ENVIRONMENT", "production/sandbox")
    update_urls
  end

  def update_urls
    if environment.to_s.downcase == "sandbox"
      @base_url = "https://sandbox-quickbooks.api.intuit.com"
      @graphql_url = "https://qb-sandbox.api.intuit.com/graphql"
    else
      @base_url = "https://quickbooks.api.intuit.com"
      @graphql_url = "https://qb.api.intuit.com/graphql"
    end
  end

  def get_dynamic_redirect_uri
    redirect_uri
  end

  def validate_config!
    raise ArgumentError, "Client ID is required" if client_id.nil? || client_id.empty? || client_id == "your_quickbooks_client_id"
    raise ArgumentError, "Client Secret is required" if client_secret.nil? || client_secret.empty? || client_secret == "your_quickbooks_client_secret"
    raise ArgumentError, "Redirect URI is required" if redirect_uri.nil? || redirect_uri.empty? || redirect_uri.include?("your-ngrok-url")
    raise ArgumentError, "Redirect URI must start with http(s)" unless redirect_uri.start_with?("http://", "https://")
    env = environment.to_s.downcase
    raise ArgumentError, "Environment must be 'sandbox' or 'production'" unless %w[sandbox production].include?(env)
  end
end
