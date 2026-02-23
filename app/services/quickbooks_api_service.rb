require "faraday"
require "json"
require "uri"
require "zlib"
require "stringio"

class QuickbooksApiService
  def initialize(config: QuickbooksConfig.new)
    @config = config
  end

  # Returns true if dimensions endpoint is accessible
  def check_dimensions_enabled(access_token:, realm_id:)
    begin
      result = fetch_dimensions(access_token: access_token, realm_id: realm_id)
      dims = result["dimensions"] || []
      dims.is_a?(Array)
    rescue => _e
      false
    end
  end

  # Fetch active custom dimension definitions via GraphQL
  # Returns: { "dimensions" => [ {"id" => "...", "name" => "..."}, ... ] }
  def fetch_dimensions(access_token:, realm_id:)
    raise ArgumentError, "access_token is required" if access_token.to_s.strip.empty?
    raise ArgumentError, "realm_id is required" if realm_id.to_s.strip.empty?

    headers = {
      "Authorization" => access_token,
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }

    query = <<~GRAPHQL
      query AppFoundationsActiveCustomDimensionDefinitions {
        appFoundationsActiveCustomDimensionDefinitions(first: 50) {
          edges {
            node {
              id
              label
              active
            }
          }
        }
      }
    GRAPHQL

    payload = { query: query }

    conn = Faraday.new(url: @config.graphql_url)
    resp = conn.post do |req|
      req.headers = headers
      req.body = JSON.dump(payload)
    end

    if resp.status != 200
      raise "GraphQL request failed: HTTP #{resp.status} - #{resp.body}"
    end

    body = JSON.parse(resp.body)
    if body["errors"]
      messages = body["errors"].map { |e| e["message"] }.join(", ")
      raise "GraphQL errors: #{messages}"
    end

    edges = body.dig("data", "appFoundationsActiveCustomDimensionDefinitions", "edges") || []
    dimensions = edges.filter_map do |edge|
      node = edge["node"]
      next unless node && node["active"]
      { "id" => node["id"], "name" => node["label"] }
    end

    { "dimensions" => dimensions }
  end

  # Fetch custom dimension values for a given definition via GraphQL
  # Returns: [ {"id"=>..., "definitionId"=>..., "label"=>..., ...}, ... ]
  def fetch_custom_dimension_values(access_token:, realm_id:, definition_id:)
    raise ArgumentError, "definition_id is required" if definition_id.to_s.strip.empty?
    headers = {
      "Authorization" => access_token,
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }

    queries = []
    # Variant 1: filters with scalar definitionId + active
    queries << <<~GRAPHQL
      query AppFoundationsActiveCustomDimensionValues_DefinitionId_Active {
        appFoundationsActiveCustomDimensionValues(first: 100, filters: { definitionId: "#{definition_id}", active: true }) {
          edges { node { id definitionId label active parentId fullyQualifiedLabel level } }
        }
      }
    GRAPHQL
    # Variant 2: filters with scalar definitionId + isActive
    queries << <<~GRAPHQL
      query AppFoundationsActiveCustomDimensionValues_DefinitionId_IsActive {
        appFoundationsActiveCustomDimensionValues(first: 100, filters: { definitionId: "#{definition_id}", isActive: true }) {
          edges { node { id definitionId label active parentId fullyQualifiedLabel level } }
        }
      }
    GRAPHQL
    # Variant 3: filters with array definitionIds + active
    queries << <<~GRAPHQL
      query AppFoundationsActiveCustomDimensionValues_DefinitionIds_Active {
        appFoundationsActiveCustomDimensionValues(first: 100, filters: { definitionIds: ["#{definition_id}"], active: true }) {
          edges { node { id definitionId label active parentId fullyQualifiedLabel level } }
        }
      }
    GRAPHQL
    # Variant 4: filters with array definitionIds + isActive
    queries << <<~GRAPHQL
      query AppFoundationsActiveCustomDimensionValues_DefinitionIds_IsActive {
        appFoundationsActiveCustomDimensionValues(first: 100, filters: { definitionIds: ["#{definition_id}"], isActive: true }) {
          edges { node { id definitionId label active parentId fullyQualifiedLabel level } }
        }
      }
    GRAPHQL

    # Variant 5: filters with scalar definitionId (no active flag)
    queries << <<~GRAPHQL
      query AppFoundationsActiveCustomDimensionValues_DefinitionId_NoActive {
        appFoundationsActiveCustomDimensionValues(first: 100, filters: { definitionId: "#{definition_id}" }) {
          edges { node { id definitionId label active parentId fullyQualifiedLabel level } }
        }
      }
    GRAPHQL
    # Variant 6: filters with array definitionIds (no active flag)
    queries << <<~GRAPHQL
      query AppFoundationsActiveCustomDimensionValues_DefinitionIds_NoActive {
        appFoundationsActiveCustomDimensionValues(first: 100, filters: { definitionIds: ["#{definition_id}"] }) {
          edges { node { id definitionId label active parentId fullyQualifiedLabel level } }
        }
      }
    GRAPHQL

    last_error = nil
    queries.each do |q|
      payload = { query: q }
      conn = Faraday.new(url: @config.graphql_url)
      resp = conn.post do |req|
        req.headers = headers
        req.body = JSON.dump(payload)
      end
      if resp.status != 200
        last_error = "HTTP #{resp.status}"
        next
      end
      body = JSON.parse(resp.body)
      if body["errors"]
        last_error = body["errors"].map { |e| e["message"] }.join(", ")
        next
      end
      edges = body.dig("data", "appFoundationsActiveCustomDimensionValues", "edges") || []
      return edges.map { |e| e["node"] }.compact
    end

    raise "GraphQL errors (all variants failed): #{last_error || "Unknown error"}"
  end

  # Fetch customers via QBO SQL endpoint (first 10 active)
  def fetch_customers(access_token:, realm_id:)
    query = "SELECT * FROM Customer WHERE Active = true MAXRESULTS 10"
    qbo_query(access_token: access_token, realm_id: realm_id, query: query)
      .fetch("Customer", [])
  end

  # Fetch items via QBO SQL endpoint (first 10 active)
  def fetch_items(access_token:, realm_id:)
    query = "SELECT * FROM Item WHERE Active = true MAXRESULTS 10"
    qbo_query(access_token: access_token, realm_id: realm_id, query: query)
      .fetch("Item", [])
  end

  # Create an invoice with a custom dimension extension
  # Returns: { id: "...", deep_link: "..." }
  def create_invoice(access_token:, realm_id:, amount:, customer_id:, item_id:, item_name:, custom_dimension_id:, custom_dimension_value:, dimension_name: nil, dimension_value_label: nil)
    raise ArgumentError, "amount is required" if amount.to_s.strip.empty?
    headers = {
      "Authorization" => access_token,
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Accept-Encoding" => "gzip, deflate"
    }

    url = File.join(@config.base_url, "v3/company/#{realm_id}/invoice?minorversion=75")
    s = ->(v) { v.nil? ? nil : v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }

    desc_text = nil
    if dimension_name || dimension_value_label
      parts = []
      parts << s.call(dimension_name) if dimension_name
      parts << s.call(dimension_value_label) if dimension_value_label
      desc_text = parts.compact.join(": ")
    end

    payload = {
      Line: [
        {
          Amount: amount.to_f,
          DetailType: "SalesItemLineDetail",
          Description: (desc_text || nil),
          CustomExtensions: [
            {
              AssociatedValues: [ { Value: s.call(custom_dimension_value), Key: s.call(custom_dimension_id) } ],
              ExtensionType: "DIMENSION"
            }
          ],
          SalesItemLineDetail: {
            ItemRef: { value: s.call(item_id), name: s.call(item_name) },
            Qty: 1,
            UnitPrice: amount.to_f
          }
        }
      ],
      CustomerRef: { value: s.call(customer_id) },
      CustomerMemo: (desc_text ? { value: desc_text } : nil),
      PrivateNote: (desc_text || nil)
    }

    conn = Faraday.new
    resp = conn.post(url) do |req|
      req.headers = headers
      req.body = JSON.dump(payload)
    end

    raise "Invoice creation failed: HTTP #{resp.status} - #{resp.body}" if resp.status != 200
    raw = resp.body
    if resp.headers && resp.headers["content-encoding"].to_s.downcase.include?("gzip")
      raw = Zlib::GzipReader.new(StringIO.new(raw)).read
    end
    data = JSON.parse(raw)
    inv_id = data.dig("Invoice", "Id")
    raise "Invoice created but ID not found" if inv_id.nil?
    deep_link = "https://app.qbo.intuit.com/app/invoice?txnId=#{inv_id}&companyId=#{realm_id}"
    { id: inv_id, deep_link: deep_link }
  end

  private

  def qbo_query(access_token:, realm_id:, query:)
    headers = {
      "Authorization" => access_token,
      "Accept" => "application/json"
    }
    base = File.join(@config.base_url, "v3/company/#{realm_id}/query")
    full_url = base + "?" + URI.encode_www_form({ query: query })
    conn = Faraday.new
    resp = conn.get(full_url, nil, headers)
    raise "Query failed: HTTP #{resp.status} - #{resp.body}" if resp.status != 200
    JSON.parse(resp.body).fetch("QueryResponse", {})
  end
end
