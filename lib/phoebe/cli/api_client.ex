defmodule Phoebe.CLI.ApiClient do
  @moduledoc """
  HTTP client for interacting with the Phoebe API.
  Handles all API communications including listing, retrieving, and publishing G-expressions.
  Uses the Req HTTP client for reliable communication.
  """

  @default_base_url "http://localhost:4000/api/v1"
  @default_timeout 30_000

  @doc """
  Tests if the API is reachable and returns connection status.
  """
  def test_connection(opts \\ []) do
    case health_check(opts) do
      {:ok, :healthy} ->
        base_url = get_base_url(opts)
        IO.puts("✓ Connected to Phoebe API at #{base_url}")
        :ok

      {:error, :unhealthy} ->
        base_url = get_base_url(opts)
        IO.puts("✗ Cannot connect to Phoebe API at #{base_url}")
        IO.puts("  Make sure the server is running and accessible")
        {:error, :connection_failed}

      {:error, reason} ->
        IO.puts("✗ Connection error: #{reason}")
        {:error, :connection_failed}
    end
  end

  def list_expressions(opts \\ []) do
    base_url = get_base_url(opts)
    search = Keyword.get(opts, :search)

    url =
      case search do
        nil -> "#{base_url}/expressions"
        query -> "#{base_url}/expressions?search=#{URI.encode(query)}"
      end

    case make_request(:get, url) do
      {:ok, %{"data" => expressions}} -> {:ok, expressions}
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, format_api_error(error)}
    end
  end

  def get_expression(name, opts \\ []) do
    base_url = get_base_url(opts)
    url = "#{base_url}/expressions/#{URI.encode(name)}"

    case make_request(:get, url) do
      {:ok, %{"data" => expression}} -> {:ok, expression}
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, format_api_error(error)}
    end
  end

  def get_expression_version(name, version, opts \\ []) do
    base_url = get_base_url(opts)
    url = "#{base_url}/expressions/#{URI.encode(name)}/versions/#{URI.encode(version)}"

    case make_request(:get, url) do
      {:ok, %{"data" => version_data}} -> {:ok, version_data}
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, format_api_error(error)}
    end
  end

  def publish_expression(expression_data, opts \\ []) do
    base_url = get_base_url(opts)
    url = "#{base_url}/expressions"

    payload = %{
      "g_expression" => expression_data
    }

    case make_request(:post, url, payload) do
      {:ok, %{"data" => response}} -> {:ok, response}
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, format_api_error(error)}
    end
  end

  def publish_version(name, version_data, opts \\ []) do
    base_url = get_base_url(opts)
    url = "#{base_url}/expressions/#{URI.encode(name)}/versions"

    payload = %{
      "version" => version_data
    }

    case make_request(:post, url, payload) do
      {:ok, %{"data" => response}} -> {:ok, response}
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, format_api_error(error)}
    end
  end

  def delete_expression(name, opts \\ []) do
    base_url = get_base_url(opts)
    url = "#{base_url}/expressions/#{URI.encode(name)}"

    case make_request(:delete, url) do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, format_api_error(error)}
    end
  end

  def delete_version(name, version, opts \\ []) do
    base_url = get_base_url(opts)
    url = "#{base_url}/expressions/#{URI.encode(name)}/versions/#{URI.encode(version)}"

    case make_request(:delete, url) do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, format_api_error(error)}
    end
  end

  def health_check(opts \\ []) do
    base_url = get_base_url(opts)
    url = "#{base_url}/expressions"

    case make_request(:get, url) do
      {:ok, _} -> {:ok, :healthy}
      {:error, _} -> {:error, :unhealthy}
    end
  end

  # Private functions

  defp get_base_url(opts) do
    Keyword.get(opts, :base_url, @default_base_url)
  end

  # Core HTTP request function using Req
  defp make_request(method, url, body \\ nil) do
    options = [
      method: method,
      url: url,
      headers: [
        {"Accept", "application/json"},
        {"Content-Type", "application/json"}
      ],
      receive_timeout: @default_timeout,
      retry: false
    ]

    # Add body for POST/PUT requests
    options =
      if body do
        Keyword.put(options, :json, body)
      else
        options
      end

    case Req.request(options) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %{status: status, body: response_body}} ->
        error_msg =
          case response_body do
            %{"error" => error} -> error
            %{"errors" => errors} -> inspect(errors)
            body when is_binary(body) -> body
            body -> inspect(body)
          end

        {:error, "HTTP #{status}: #{error_msg}"}

      {:error, %{reason: reason}} ->
        {:error, "Request failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "Request error: #{Exception.message(error)}"}
  end

  def format_api_error(error_message) do
    case error_message do
      "HTTP 404: " <> _ -> "Expression not found"
      "HTTP 422: " <> details -> "Validation error: #{details}"
      "HTTP 500: " <> _ -> "Server error"
      "Request failed: " <> details -> "Connection error: #{details}"
      "Request error: " <> details -> "Request error: #{details}"
      other -> other
    end
  end

  @doc """
  Checks if the API is reachable without printing status messages.
  Returns true if healthy, false otherwise.
  """
  def api_available?(opts \\ []) do
    case health_check(opts) do
      {:ok, :healthy} -> true
      _ -> false
    end
  end
end
