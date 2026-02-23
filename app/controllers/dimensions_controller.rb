class DimensionsController < ApplicationController
  def values
    begin
      access_token = session[:access_token]
      realm_id = session[:realm_id]
      definition_id = params[:dimension_id]

      if access_token.blank? || realm_id.blank?
        return render json: { error: "Not authenticated" }, status: :unauthorized
      end
      if definition_id.blank?
        return render json: { error: "Missing dimension_id" }, status: :bad_request
      end

      api = QuickbooksApiService.new
      values = api.fetch_custom_dimension_values(
        access_token: access_token,
        realm_id: realm_id,
        definition_id: definition_id
      )
      render json: { values: values }
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
end
