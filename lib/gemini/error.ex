defmodule Gemini.Error do
  @moduledoc """
  Standardized error structure for Gemini client.
  """

  use TypedStruct

  typedstruct do
    field(:type, atom(), enforce: true)
    field(:message, String.t(), enforce: true)
    field(:http_status, integer() | nil, default: nil)
    field(:api_reason, term() | nil, default: nil)
    field(:details, map() | nil, default: nil)
    field(:original_error, term() | nil, default: nil)
  end

  @typedoc "The type of error."
  @type error_type :: atom()

  @typedoc "A human-readable message describing the error."
  @type error_message :: String.t()

  @typedoc "The HTTP status code, if the error originated from an HTTP response."
  @type http_status :: integer() | nil

  @typedoc "API-specific error code or reason, if provided by Gemini."
  @type api_reason :: term() | nil

  @typedoc "Additional details or context about the error."
  @type error_details :: map() | nil

  @typedoc "The original error term, if this error is wrapping another."
  @type original_error :: term() | nil

  @doc """
  Create a new error with type and message.
  """
  def new(type, message, attrs \\ []) do
    struct!(__MODULE__, [{:type, type}, {:message, message} | attrs])
  end

  @doc """
  Create an HTTP error.
  """
  def http_error(status, message, details \\ %{}) do
    new(:http_error, message, http_status: status, details: details)
  end

  @doc """
  Create an API error from Gemini response.
  """
  def api_error(reason, message, details \\ %{}) do
    http_status =
      case reason do
        status when is_integer(status) -> status
        _ -> nil
      end

    new(:api_error, message,
      api_reason: reason,
      http_status: http_status,
      details: details
    )
  end

  @doc """
  Create a configuration error.
  """
  def config_error(message, details \\ %{}) do
    new(:config_error, message, details: details)
  end

  @doc """
  Create a request validation error.
  """
  def validation_error(message, details \\ %{}) do
    new(:validation_error, message, details: details)
  end

  @doc """
  Create a JSON serialization/deserialization error.
  """
  def serialization_error(message, details \\ %{}) do
    new(:serialization_error, message, details: details)
  end

  @doc """
  Create a network/connection error.
  """
  def network_error(message, original_error \\ nil) do
    new(:network_error, message, original_error: original_error)
  end

  @doc """
  Create an invalid response error.
  """
  def invalid_response(message, details \\ %{}) do
    new(:invalid_response, message, details: details)
  end
end
