Rails.application.routes.draw do
  get "home/index"

  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root to: "home#index"

  # OAuth endpoints
  get "/qbo-login", to: "auth#qbo_login"
  get "/callback", to: "auth#callback"
  # Datafetch endpoint
  post "/datafetch", to: "data#fetch"
  # JSON endpoint to get dimension values
  get "/get_dimension_values/:dimension_id", to: "dimensions#values"
  # Create invoice
  post "/create_invoice", to: "invoices#create"
  # Logout
  get "/logout", to: "sessions#logout"
end



  
