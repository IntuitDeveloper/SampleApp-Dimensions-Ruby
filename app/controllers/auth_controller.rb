class AuthController < ApplicationController

    # OAuth login flow
    def qbo_login
    begin
      url = QuickbooksOauthService.new.authorization_url
      redirect_to url, allow_other_host: true
    rescue => e
      flash[:error] = "OAuth initialization failed: #{e.message}"
      redirect_to root_path
    end
  end

  # OAuth callback
  def callback
    begin
      auth_code = params[:code]
      realm_id = params[:realmId]
      if auth_code.blank? || realm_id.blank?
        flash[:error] = "Missing authorization code or realm ID"
        return redirect_to root_path
      end

      token_data = QuickbooksOauthService.new.exchange_code_for_token(auth_code: auth_code, realm_id: realm_id)
      s = ->(v) { v.nil? ? nil : v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }
      access_token = token_data["access_token"]
      session[:access_token] = s.call("Bearer #{access_token}")
      session[:refresh_token] = s.call(token_data["refresh_token"]) 
      session[:realm_id] = s.call(token_data["realm_id"] || realm_id)

      # Reset dimensions state; user must fetch dimensions again after a new connect
      session.delete(:dimensions)
      session.delete(:dimensions_names)
      session.delete(:dimensions_map)
      session[:dimensions_fetched] = false

      # Try dimensions check
      begin
        enabled = QuickbooksApiService.new.check_dimensions_enabled(access_token: session[:access_token], realm_id: session[:realm_id])
        session[:dimensions_enabled] = enabled
        flash[:success] = enabled ? "Successfully connected to QuickBooks! Dimensions is enabled." : "Connected to QuickBooks, but Dimensions is not enabled. Please enable Dimensions in QuickBooks to use this feature."
      rescue => e
        session[:dimensions_enabled] = false
        flash[:success] = "Successfully connected to QuickBooks! (Could not verify Dimensions status)"
      end

      # Prefetch customers and items
      begin
        api = QuickbooksApiService.new
        customers = api.fetch_customers(access_token: session[:access_token], realm_id: session[:realm_id])
        items = api.fetch_items(access_token: session[:access_token], realm_id: session[:realm_id])
        # Store server-side to avoid CookieOverflow (4KB cookie limit)
        Rails.cache.write("qbo:#{session[:realm_id]}:customers", customers, expires_in: 15.minutes)
        Rails.cache.write("qbo:#{session[:realm_id]}:items", items, expires_in: 15.minutes)
      rescue => e
      end

    rescue => e
      session[:dimensions_enabled] = false
      flash[:error] = "Authentication failed: #{e.message}"
    end
    redirect_to root_path
  end
end
