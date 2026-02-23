# SampleApp-Dimensions-Ruby

This is a Ruby on Rails sample that demonstrates integrating with QuickBooks using OAuth 2.0 to:
- Fetch custom Dimensions (definitions and values) via GraphQL
- Create an Invoice with a selected Dimension value
It ships with a minimal UI at `/` implementing a multi-step workflow.

## Features

- **OAuth 2.0** authentication with QuickBooks
- **Fetch custom Dimensions** (definitions and values) via GraphQL endpoint
- **Create Invoice** with a custom Dimension value
- Minimal UI workflow at `/`

## Prerequisites

- Ruby 3.4.7
- Rails 8.x
- QuickBooks Online developer account and IES company for API access(Kindly note that the IES company requires defined dimensions and customers in order to complete the process.).
- ngrok (for local development HTTPS callback)

## Setup

1) **Clone or download the repository:**

```bash
git clone <repository-url>
cd SampleApp-Dimensions-Ruby
```

2) **Install dependencies**

```bash
bundle install
```

3) **Configure environment**

- Copy `.env.example` to `.env` and set real values

```bash
cp .env.example .env
```

Required variables:

```bash
QB_CLIENT_ID=your_actual_client_id
QB_CLIENT_SECRET=your_actual_client_secret
QB_REDIRECT_URI=https://your-ngrok-url.ngrok-free.app/callback
QB_ENVIRONMENT=sandbox   # or production
```

4) **Expose your dev server via ngrok**

If this is your first time using ngrok:

Sign up / log in at https://ngrok.com and download/install ngrok for your OS.

From your ngrok dashboard, copy your Auth Token.

Run the following once to configure ngrok locally (replace with your token):

```bash
ngrok config add-authtoken YOUR_NGROK_AUTH_TOKEN
```

Then, in a separate terminal window, start ngrok on the Rails port:

```bash
ngrok http 5036
```
  - ngrok will show an **HTTPS** forwarding URL, e.g. `https://abc123.ngrok-free.app`.
  - Use this HTTPS URL as the base for `QB_REDIRECT_URI` and in your QuickBooks app settings.
  - The redirect path must end with `/callback`, e.g. `https://abc123.ngrok-free.app/callback`.

5) **Run the app**

```bash
bin/rails server
```
Note: If you encounter a permission denied error during this step, try running the app using the following command:

```bash
bundle exec rails server
```

**Configure your QuickBooks app:**
   - Go to [Intuit Developer Portal](https://developer.intuit.com/app/developer/myapps)
   - Create a new app or use an existing one
   - Enable Accounting and Custom Dimensions API scopes
   - Add your redirect URI (e.g., `https://your-ngrok-url.ngrok-free.app/callback`)

   ### Required OAuth Scopes

   The app uses the following scopes (see `QuickbooksOauthService`):
   - `com.intuit.quickbooks.accounting`
   - `app-foundations.custom-dimensions.read`

## Usage

1. Visit `http://localhost:5036` in your browser
2. **Step 1: Connect to QuickBooks** - Click "Connect to QuickBooks" to authenticate via OAuth 2.0
3. **Step 2: Fetch Dimensions** - Click "Fetch Dimensions" to load available custom dimension definitions
4. **Step 3: Create Invoice** - Enter amount, select a customer and item, choose a dimension and value, then click "Create Invoice"

Visit:
- UI: http://localhost:5036/

## Endpoints

- `/` – Minimal UI with the multi-step workflow
- `/qbo-login` – Initiates OAuth flow
- `/callback` – OAuth callback handler
- `/datafetch` – POST; loads dimensions into session
- `/get_dimension_values/:dimension_id` – GET; returns JSON of values for a dimension
- `/create_invoice` – POST; creates an invoice
- `/logout` – Clears session

## Dependencies

### Runtime

- **rails (~> 8.0.3)**
  Full-stack web framework (routing, controllers, views, etc.).

- **puma (>= 5.0)**
  HTTP server that runs the Rails app.

- **propshaft**
  Modern Rails asset pipeline for serving CSS/JS/images.

- **importmap-rails**
  Loads JavaScript modules via ESM without Node/bundlers.

- **graphql (~> 2.5)**
  GraphQL gem used internally to structure requests; no public `/graphql` endpoint is exposed.

- **faraday (~> 2.14)**
  HTTP client for calling QuickBooks APIs.

- **dotenv-rails (~> 3.1)**
  Loads environment variables from `.env` in development.

- **tzinfo-data (Windows/JRuby only)**
  Time zone data for platforms lacking system zoneinfo.

### System/Platform Requirements

- **Ruby 3.4.7**
  Project Ruby version (`.ruby-version`).

### Optional/Environment-Dependent

- **ngrok (external tool)**
  Used to expose a public HTTPS URL for OAuth callbacks in development.


## Notes on GraphQL
- The app issues GraphQL calls to Intuit endpoints internally (see `app/services/quickbooks_api_service.rb`).
- Use the UI flow for primary functionality,there is no public `/graphql` route.

## Implementation notes

- OAuth and API services:
  - `app/services/quickbooks_config.rb`
  - `app/services/quickbooks_oauth_service.rb`
  - `app/services/quickbooks_api_service.rb`
- GraphQL:
  - Controller: `app/controllers/graphql_controller.rb` (context includes services + session tokens)
- Controllers/UI:
  - Root and minimal UI: `HomeController#index`, `app/views/home/index.html.erb`
  - OAuth: `AuthController` (`/qbo-login`, `/callback`)
  - Data: `DataController#fetch`
  - Dimensions JSON: `DimensionsController#values`
  - Invoice: `InvoicesController#create`
  - Logout: `SessionsController#logout`
