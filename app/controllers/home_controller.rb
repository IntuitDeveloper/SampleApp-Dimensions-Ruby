class HomeController < ApplicationController
    def index
        @authenticated = session[:access_token].present?
        @realm_id = session[:realm_id]

        # Dimensions metadata (set by DataController#fetch)
        @dimensions = session[:dimensions] || []
        @dimensions_names = session[:dimensions_names] || []
        @dimensions_map = session[:dimensions_map] || {}
        @dimensions_fetched = session[:dimensions_fetched] || false
        @dimensions_enabled = session[:dimensions_enabled] || false

        # Prefetched data stored server-side cache in AuthController#callback
        @customers = @realm_id.present? ? Rails.cache.read("qbo:#{@realm_id}:customers") : nil
        @items = @realm_id.present? ? Rails.cache.read("qbo:#{@realm_id}:items") : nil

        # Invoice info (set by InvoicesController#create)
        @invoice_id = session[:invoice_id]
        @invoice_deep_link = session[:invoice_deep_link]
        @invoice_success = session[:invoice_success] || false
    end
end
