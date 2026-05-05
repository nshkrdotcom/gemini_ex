defmodule Gemini.GovernedAuthority do
  @moduledoc """
  Authority-materialized Gemini inputs for governed execution.

  Standalone GeminiEx usage keeps using its normal env, app config, ADC, native
  Google credential discovery, and request/session overrides. Governed usage
  passes this value after an external authority has selected the credential,
  lease, target, redaction policy, base URL, and materialized credential data
  for one bounded effect.
  """

  @type header_map :: %{optional(String.t()) => String.t()}
  @type query_params :: [{String.t(), String.t()}]

  @type t :: %__MODULE__{
          base_url: String.t(),
          websocket_path: String.t() | nil,
          provider_ref: String.t(),
          provider_account_ref: String.t(),
          model_account_ref: String.t(),
          endpoint_ref: String.t(),
          credential_ref: String.t(),
          credential_lease_ref: String.t(),
          target_ref: String.t(),
          operation_policy_ref: String.t(),
          redaction_ref: String.t() | nil,
          headers: header_map(),
          credential_headers: header_map(),
          credential_query_params: query_params()
        }

  @enforce_keys [
    :base_url,
    :provider_ref,
    :provider_account_ref,
    :model_account_ref,
    :endpoint_ref,
    :credential_ref,
    :credential_lease_ref,
    :target_ref,
    :operation_policy_ref
  ]
  defstruct base_url: nil,
            websocket_path: nil,
            provider_ref: nil,
            provider_account_ref: nil,
            model_account_ref: nil,
            endpoint_ref: nil,
            credential_ref: nil,
            credential_lease_ref: nil,
            target_ref: nil,
            operation_policy_ref: nil,
            redaction_ref: nil,
            headers: %{},
            credential_headers: %{},
            credential_query_params: []

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = authority), do: validate!(authority)

  def new!(opts) when is_list(opts) do
    opts
    |> Map.new()
    |> new!()
  end

  def new!(%{} = opts) do
    authority = %__MODULE__{
      base_url: required_string!(opts, :base_url),
      websocket_path: optional_string(opts, :websocket_path),
      provider_ref: required_string!(opts, :provider_ref),
      provider_account_ref: required_string!(opts, :provider_account_ref),
      model_account_ref: required_string!(opts, :model_account_ref),
      endpoint_ref: required_string!(opts, :endpoint_ref),
      credential_ref: required_string!(opts, :credential_ref),
      credential_lease_ref: required_string!(opts, :credential_lease_ref),
      target_ref: required_string!(opts, :target_ref),
      operation_policy_ref: required_string!(opts, :operation_policy_ref),
      redaction_ref: optional_string(opts, :redaction_ref),
      headers: normalize_headers(fetch_value(opts, :headers, %{})),
      credential_headers: normalize_headers(fetch_value(opts, :credential_headers, %{})),
      credential_query_params:
        normalize_query_params(fetch_value(opts, :credential_query_params, []))
    }

    validate!(authority)
  end

  @spec headers(t()) :: [{String.t(), String.t()}]
  def headers(%__MODULE__{} = authority) do
    authority.headers
    |> Map.merge(authority.credential_headers)
    |> Enum.map(fn {name, value} -> {name, value} end)
  end

  @spec refs(t()) :: map()
  def refs(%__MODULE__{} = authority) do
    %{
      provider_ref: authority.provider_ref,
      provider_account_ref: authority.provider_account_ref,
      model_account_ref: authority.model_account_ref,
      endpoint_ref: authority.endpoint_ref,
      credential_ref: authority.credential_ref,
      credential_lease_ref: authority.credential_lease_ref,
      target_ref: authority.target_ref,
      operation_policy_ref: authority.operation_policy_ref,
      redaction_ref: authority.redaction_ref
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  @spec credential_materialized?(t()) :: boolean()
  def credential_materialized?(%__MODULE__{} = authority) do
    map_size(authority.credential_headers) > 0 or authority.credential_query_params != []
  end

  defp validate!(%__MODULE__{} = authority) do
    if credential_materialized?(authority) do
      authority
    else
      raise ArgumentError, "governed authority requires credential headers or query params"
    end
  end

  defp required_string!(opts, key) do
    case optional_string(opts, key) do
      value when is_binary(value) and value != "" ->
        value

      _other ->
        raise ArgumentError, "governed authority requires #{key}"
    end
  end

  defp optional_string(opts, key) do
    case fetch_value(opts, key, nil) do
      nil -> nil
      value when is_binary(value) -> value
      value when is_atom(value) -> Atom.to_string(value)
      value -> to_string(value)
    end
  end

  defp fetch_value(opts, key, default) when is_map(opts) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(opts, key) -> Map.get(opts, key)
      Map.has_key?(opts, string_key) -> Map.get(opts, string_key)
      true -> default
    end
  end

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    if Enum.all?(headers, &tuple_pair?/1) do
      Map.new(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
    else
      %{}
    end
  end

  defp normalize_headers(_headers), do: %{}

  defp normalize_query_params(params) when is_map(params) do
    params
    |> Enum.map(fn {name, value} -> {to_string(name), to_string(value)} end)
    |> Enum.sort_by(fn {name, _value} -> name end)
  end

  defp normalize_query_params(params) when is_list(params) do
    if Enum.all?(params, &tuple_pair?/1) do
      Enum.map(params, fn {name, value} -> {to_string(name), to_string(value)} end)
    else
      []
    end
  end

  defp normalize_query_params(_params), do: []

  defp tuple_pair?({_name, _value}), do: true
  defp tuple_pair?(_entry), do: false
end
