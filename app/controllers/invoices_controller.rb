class InvoicesController < ApplicationController
  def create
    begin
      session.delete(:invoice_id)
      session.delete(:invoice_deep_link)
      session.delete(:invoice_success)

      amount = params[:amount]
      access_token = session[:access_token]
      realm_id = session[:realm_id]
      custom_dimension_id = params[:custom_dimension_id]
      custom_dimension_value = params[:custom_dimension_value]
      custom_dimension_name = params[:custom_dimension_name]
      custom_dimension_value_label = params[:custom_dimension_value_label]
      customer_id = params[:customer_id]
      item_id = params[:item_id]
      item_name = params[:item_name]

      if access_token.blank? || realm_id.blank? || amount.blank? || custom_dimension_id.blank? || custom_dimension_value.blank? || customer_id.blank? || item_id.blank?
        flash[:error] = "Connect to QuickBooks and select all required fields."
        return redirect_to root_path
      end

      s = ->(v) { v.nil? ? nil : v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }

      api = QuickbooksApiService.new
      result = api.create_invoice(
        access_token: access_token,
        realm_id: realm_id,
        amount: amount,
        customer_id: customer_id,
        item_id: item_id,
        item_name: item_name,
        custom_dimension_id: custom_dimension_id,
        custom_dimension_value: custom_dimension_value,
        dimension_name: custom_dimension_name,
        dimension_value_label: custom_dimension_value_label
      )

      session[:invoice_id] = s.call(result[:id])
      session[:invoice_deep_link] = s.call(result[:deep_link])
      session[:invoice_success] = true
      flash[:success] = s.call("Success! Invoice #{result[:id]} created with Dimension ID: #{custom_dimension_id}")
    rescue => e
      s = ->(v) { v.nil? ? nil : v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }
      flash[:error] = s.call("Error creating invoice: #{e.message}")
      session.delete(:invoice_success)
    end
    redirect_to root_path
  end
end
