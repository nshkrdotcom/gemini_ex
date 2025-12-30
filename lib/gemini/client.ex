defmodule Gemini.Client do
  @moduledoc """
  Main client module that delegates to the appropriate HTTP client implementation.

  This module provides a unified interface for making HTTP requests to the Gemini API,
  abstracting away the specific implementation details of the underlying HTTP client.
  """

  alias Gemini.Client.HTTP

  @doc """
  Make a GET request using the configured authentication.

  ## Parameters
  - `path` - The API path to request
  - `opts` - Optional keyword list of request options

  ## Returns
  - `{:ok, response}` - Successful response
  - `{:error, Error.t()}` - Error details
  """
  defdelegate get(path, opts \\ []), to: HTTP

  @doc """
  Make a POST request using the configured authentication.

  ## Parameters
  - `path` - The API path to request
  - `body` - The request body (will be JSON encoded)
  - `opts` - Optional keyword list of request options

  ## Returns
  - `{:ok, response}` - Successful response
  - `{:error, Error.t()}` - Error details
  """
  defdelegate post(path, body, opts \\ []), to: HTTP

  @doc """
  Make an authenticated HTTP request.

  ## Parameters
  - `method` - HTTP method (:get, :post, etc.)
  - `path` - The API path to request
  - `body` - The request body (nil for GET requests)
  - `auth_config` - Authentication configuration
  - `opts` - Optional keyword list of request options

  ## Returns
  - `{:ok, response}` - Successful response
  - `{:error, Error.t()}` - Error details
  """
  defdelegate request(method, path, body, auth_config, opts \\ []), to: HTTP
end
