class DataController < ApplicationController
  def fetch
    begin
      access_token = session[:access_token]
      realm_id = session[:realm_id]
      if access_token.blank? || realm_id.blank?
        flash[:error] = "Please authenticate with QuickBooks first"
        return redirect_to root_path
      end

      api = QuickbooksApiService.new
      dimensions_result = api.fetch_dimensions(access_token: access_token, realm_id: realm_id)

      dimensions = dimensions_result["dimensions"] || []

      s = ->(v) { v.nil? ? nil : v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }
      dimensions_names = dimensions.map { |e| s.call(e["name"]) }
      dimensions_map = dimensions.map { |e| [s.call(e["id"]), s.call(e["name"]) ] }.to_h

      session[:dimensions_names] = dimensions_names
      session[:dimensions_map] = dimensions_map
      session[:dimensions] = dimensions_names
      session[:dimensions_fetched] = true

      flash[:success] = "Successfully loaded #{dimensions_names.length} dimension!"
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
    redirect_to root_path
  end
end
