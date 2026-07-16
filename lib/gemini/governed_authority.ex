defmodule Gemini.GovernedAuthority.MaterializationRequest do
  @moduledoc """
  Secret-free binding for one transient Gemini credential materialization.

  This provider-local type intentionally mirrors the frozen
  `jido.credential-materialization.v1` request without making GeminiEx depend on
  Jido. It is safe to inspect and include in telemetry or receipts.
  """

  @account_fields [
    :provider_family,
    :account_ref,
    :tenant_id,
    :connection_id,
    :endpoint_ref,
    :quota_scope_ref,
    :generation,
    :fence
  ]

  @fields [
    :materialization_ref,
    :lease_id,
    :account,
    :effect_ref,
    :operation_ref,
    :authority_ref,
    :endpoint_ref,
    :target_ref,
    :issued_at,
    :expires_at
  ]

  @enforce_keys @fields
  defstruct @fields

  @type account :: %{
          provider_family: String.t(),
          account_ref: String.t(),
          tenant_id: String.t(),
          connection_id: String.t(),
          endpoint_ref: String.t(),
          quota_scope_ref: String.t(),
          generation: pos_integer(),
          fence: non_neg_integer()
        }

  @type t :: %__MODULE__{
          materialization_ref: String.t(),
          lease_id: String.t(),
          account: account(),
          effect_ref: String.t(),
          operation_ref: String.t(),
          authority_ref: String.t(),
          endpoint_ref: String.t(),
          target_ref: String.t(),
          issued_at: DateTime.t(),
          expires_at: DateTime.t()
        }

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = request), do: validate!(request)

  def new!(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = normalize_attrs(attrs)
    ensure_known_fields!(attrs, @fields, "materialization request")

    request = %__MODULE__{
      materialization_ref: required_string!(attrs, :materialization_ref),
      lease_id: required_string!(attrs, :lease_id),
      account: normalize_account!(fetch_value(attrs, :account)),
      effect_ref: required_string!(attrs, :effect_ref),
      operation_ref: required_string!(attrs, :operation_ref),
      authority_ref: required_string!(attrs, :authority_ref),
      endpoint_ref: required_string!(attrs, :endpoint_ref),
      target_ref: required_string!(attrs, :target_ref),
      issued_at: required_datetime!(attrs, :issued_at),
      expires_at: required_datetime!(attrs, :expires_at)
    }

    validate!(request)
  end

  def new!(_attrs), do: raise(ArgumentError, "invalid governed materialization request")

  @spec valid_now?(t(), DateTime.t()) :: boolean()
  def valid_now?(%__MODULE__{expires_at: expires_at}, %DateTime{} = now) do
    DateTime.compare(expires_at, now) == :gt
  end

  defp validate!(%__MODULE__{} = request) do
    account = normalize_account!(request.account)

    Enum.each(
      [
        :materialization_ref,
        :lease_id,
        :effect_ref,
        :operation_ref,
        :authority_ref,
        :endpoint_ref,
        :target_ref
      ],
      &required_string!(Map.from_struct(request), &1)
    )

    unless is_struct(request.issued_at, DateTime) and is_struct(request.expires_at, DateTime) do
      raise ArgumentError, "governed materialization requires issued_at and expires_at"
    end

    request = %{request | account: account}

    cond do
      request.endpoint_ref != account.endpoint_ref ->
        raise ArgumentError, "governed materialization endpoint binding does not match account"

      DateTime.compare(request.expires_at, request.issued_at) != :gt ->
        raise ArgumentError, "governed materialization expires_at must be after issued_at"

      not valid_now?(request, DateTime.utc_now()) ->
        raise ArgumentError, "governed materialization is expired"

      true ->
        request
    end
  end

  defp normalize_account!(account) when is_map(account) or is_list(account) do
    account = normalize_attrs(account)
    ensure_known_fields!(account, @account_fields, "managed account")

    normalized = %{
      provider_family: required_string!(account, :provider_family),
      account_ref: required_string!(account, :account_ref),
      tenant_id: required_string!(account, :tenant_id),
      connection_id: required_string!(account, :connection_id),
      endpoint_ref: required_string!(account, :endpoint_ref),
      quota_scope_ref: required_string!(account, :quota_scope_ref),
      generation: fetch_value(account, :generation),
      fence: fetch_value(account, :fence)
    }

    unless is_integer(normalized.generation) and normalized.generation > 0 do
      raise ArgumentError, "governed materialization requires positive account generation"
    end

    unless is_integer(normalized.fence) and normalized.fence >= 0 do
      raise ArgumentError, "governed materialization requires non-negative account fence"
    end

    normalized
  end

  defp normalize_account!(_account),
    do: raise(ArgumentError, "governed materialization requires account")

  defp required_datetime!(attrs, key) do
    case fetch_value(attrs, key) do
      %DateTime{} = value -> value
      _other -> raise ArgumentError, "governed materialization requires #{key}"
    end
  end

  defp required_string!(attrs, key) do
    case fetch_value(attrs, key) do
      value when is_binary(value) and value != "" -> value
      _other -> raise ArgumentError, "governed materialization requires #{key}"
    end
  end

  defp normalize_attrs(%{__struct__: _module} = attrs), do: Map.from_struct(attrs)
  defp normalize_attrs(attrs), do: Map.new(attrs)

  defp ensure_known_fields!(attrs, fields, name) do
    allowed = MapSet.new(Enum.flat_map(fields, &[&1, Atom.to_string(&1)]))

    unless Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, &1)) do
      raise ArgumentError, "governed #{name} contains unknown fields"
    end
  end

  defp fetch_value(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end
end

defmodule Gemini.GovernedAuthority.SecretMaterial do
  @moduledoc """
  Transient Gemini credential material.

  Only this type may contain provider credential headers or query parameters.
  Inspection exposes binding metadata and credential field names, never values;
  durable JSON encoding is prohibited.
  """

  @fields [:materialization_ref, :provider_family, :account_ref, :generation, :payload]
  @enforce_keys @fields
  defstruct @fields

  @type header_map :: %{optional(String.t()) => String.t()}
  @type query_params :: [{String.t(), String.t()}]
  @type t :: %__MODULE__{
          materialization_ref: String.t(),
          provider_family: String.t(),
          account_ref: String.t(),
          generation: pos_integer(),
          payload: %{headers: header_map(), query_params: query_params()}
        }

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = material), do: validate!(material)

  def new!(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = normalize_attrs(attrs)
    ensure_known_fields!(attrs, @fields)
    payload = normalize_payload!(fetch_value(attrs, :payload))

    material = %__MODULE__{
      materialization_ref: required_string!(attrs, :materialization_ref),
      provider_family: required_string!(attrs, :provider_family),
      account_ref: required_string!(attrs, :account_ref),
      generation: fetch_value(attrs, :generation),
      payload: payload
    }

    validate!(material)
  end

  def new!(_attrs), do: raise(ArgumentError, "invalid governed secret material")

  @spec headers(t()) :: header_map()
  def headers(%__MODULE__{payload: %{headers: headers}}), do: headers

  @spec query_params(t()) :: query_params()
  def query_params(%__MODULE__{payload: %{query_params: params}}), do: params

  @spec secret_values(t()) :: [String.t()]
  def secret_values(%__MODULE__{} = material) do
    Map.values(headers(material)) ++ Enum.map(query_params(material), &elem(&1, 1))
  end

  @spec redacted(t()) :: map()
  def redacted(%__MODULE__{} = material) do
    %{
      materialization_ref: material.materialization_ref,
      provider_family: material.provider_family,
      account_ref: material.account_ref,
      generation: material.generation,
      payload: %{
        header_names: material |> headers() |> Map.keys() |> Enum.sort(),
        query_names: material |> query_params() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
      }
    }
  end

  defp validate!(%__MODULE__{} = material) do
    attrs = Map.from_struct(material)

    Enum.each(
      [:materialization_ref, :provider_family, :account_ref],
      &required_string!(attrs, &1)
    )

    unless is_integer(material.generation) and material.generation > 0 do
      raise ArgumentError, "governed secret material requires positive generation"
    end

    if map_size(headers(material)) == 0 and query_params(material) == [] do
      raise ArgumentError, "governed secret material requires credential headers or query params"
    end

    material
  end

  defp normalize_payload!(payload) when is_map(payload) or is_list(payload) do
    payload = normalize_attrs(payload)
    ensure_known_fields!(payload, [:headers, :query_params])

    %{
      headers: normalize_headers(fetch_value(payload, :headers, %{})),
      query_params: normalize_query_params(fetch_value(payload, :query_params, []))
    }
  end

  defp normalize_payload!(_payload),
    do: raise(ArgumentError, "governed secret material requires payload")

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {name, value} -> normalize_pair!(name, value) end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    if Enum.all?(headers, &match?({_, _}, &1)) do
      Map.new(headers, fn {name, value} -> normalize_pair!(name, value) end)
    else
      raise ArgumentError, "governed secret material headers must be key/value pairs"
    end
  end

  defp normalize_headers(_headers),
    do: raise(ArgumentError, "governed secret material headers must be a map or keyword list")

  defp normalize_query_params(params) when is_map(params) do
    params
    |> Enum.map(fn {name, value} -> normalize_pair!(name, value) end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp normalize_query_params(params) when is_list(params) do
    if Enum.all?(params, &match?({_, _}, &1)) do
      Enum.map(params, fn {name, value} -> normalize_pair!(name, value) end)
    else
      raise ArgumentError, "governed secret material query params must be key/value pairs"
    end
  end

  defp normalize_query_params(_params),
    do: raise(ArgumentError, "governed secret material query params must be a map or list")

  defp normalize_pair!(name, value) do
    name = to_string(name) |> String.trim()
    value = to_string(value)

    if name == "" or value == "" do
      raise ArgumentError, "governed secret material names and values must be present"
    end

    {name, value}
  end

  defp required_string!(attrs, key) do
    case fetch_value(attrs, key) do
      value when is_binary(value) and value != "" -> value
      _other -> raise ArgumentError, "governed secret material requires #{key}"
    end
  end

  defp normalize_attrs(%{__struct__: _module} = attrs), do: Map.from_struct(attrs)
  defp normalize_attrs(attrs), do: Map.new(attrs)

  defp ensure_known_fields!(attrs, fields) do
    allowed = MapSet.new(Enum.flat_map(fields, &[&1, Atom.to_string(&1)]))

    unless Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, &1)) do
      raise ArgumentError, "governed secret material contains unknown fields"
    end
  end

  defp fetch_value(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end
end

defimpl Inspect, for: Gemini.GovernedAuthority.SecretMaterial do
  import Inspect.Algebra

  def inspect(material, opts) do
    concat([
      "#Gemini.GovernedAuthority.SecretMaterial<",
      to_doc(Gemini.GovernedAuthority.SecretMaterial.redacted(material), opts),
      ">"
    ])
  end
end

defimpl Jason.Encoder, for: Gemini.GovernedAuthority.SecretMaterial do
  def encode(_material, _opts) do
    raise ArgumentError, "governed secret material is transient and cannot be durably encoded"
  end
end

defmodule Gemini.GovernedAuthority do
  @moduledoc """
  Exact, transient authority-materialization boundary for managed Gemini calls.

  Standalone GeminiEx calls may still use explicit per-request or configured
  credentials. Governed calls accept credentials only through a frozen-contract
  shaped materialization request plus separately typed secret material. The
  request binds account generation, quota scope, lease, authority, operation,
  endpoint, target, effect, and expiry before any lower HTTP effect occurs.
  """

  alias __MODULE__.{MaterializationRequest, SecretMaterial}

  @legacy_secret_fields [:credential_ref, :credential_headers, :credential_query_params]
  @input_fields [
    :base_url,
    :websocket_path,
    :provider_ref,
    :model_account_ref,
    :credential_handle_ref,
    :operation_policy_ref,
    :redaction_ref,
    :headers,
    :materialization_request,
    :secret_material
  ]
  @credential_header_names ~w(
    authorization proxy_authorization x_goog_api_key x_api_key api_key cookie set_cookie
  )
  @credential_request_keys ~w(
    api_key access_token auth_token authorization client_secret private_key
    service_account service_account_data service_account_key credential_headers
    credential_query_params credential_materialization
  )

  @type header_map :: %{optional(String.t()) => String.t()}
  @type query_params :: [{String.t(), String.t()}]

  @type t :: %__MODULE__{
          base_url: String.t(),
          websocket_path: String.t() | nil,
          provider_ref: String.t(),
          model_account_ref: String.t(),
          credential_handle_ref: String.t(),
          operation_policy_ref: String.t(),
          redaction_ref: String.t() | nil,
          headers: header_map(),
          materialization_request: MaterializationRequest.t(),
          secret_material: SecretMaterial.t(),
          credential_query_params: query_params()
        }

  @enforce_keys [
    :base_url,
    :provider_ref,
    :model_account_ref,
    :credential_handle_ref,
    :operation_policy_ref,
    :materialization_request,
    :secret_material
  ]
  defstruct base_url: nil,
            websocket_path: nil,
            provider_ref: nil,
            model_account_ref: nil,
            credential_handle_ref: nil,
            operation_policy_ref: nil,
            redaction_ref: nil,
            headers: %{},
            materialization_request: nil,
            secret_material: nil,
            # Live transports consume this derived projection. Constructor
            # input is rejected so SecretMaterial remains the only authority.
            credential_query_params: []

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = authority), do: validate!(authority)

  def new!(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = normalize_attrs(attrs)
    reject_legacy_secret_fields!(attrs)
    ensure_known_fields!(attrs)

    request =
      attrs
      |> fetch_value(:materialization_request)
      |> MaterializationRequest.new!()

    secret_material =
      attrs
      |> fetch_value(:secret_material)
      |> SecretMaterial.new!()

    authority = %__MODULE__{
      base_url: required_string!(attrs, :base_url),
      websocket_path: optional_string(attrs, :websocket_path),
      provider_ref: required_string!(attrs, :provider_ref),
      model_account_ref: required_string!(attrs, :model_account_ref),
      credential_handle_ref: required_string!(attrs, :credential_handle_ref),
      operation_policy_ref: required_string!(attrs, :operation_policy_ref),
      redaction_ref: optional_string(attrs, :redaction_ref),
      headers: normalize_headers(fetch_value(attrs, :headers, %{})),
      materialization_request: request,
      secret_material: secret_material,
      credential_query_params: SecretMaterial.query_params(secret_material)
    }

    validate!(authority)
  end

  @spec headers(t()) :: [{String.t(), String.t()}]
  def headers(%__MODULE__{} = authority) do
    authority.headers
    |> Map.merge(SecretMaterial.headers(authority.secret_material))
    |> Enum.map(fn {name, value} -> {name, value} end)
  end

  @spec query_params(t()) :: query_params()
  def query_params(%__MODULE__{} = authority),
    do: SecretMaterial.query_params(authority.secret_material)

  @spec secret_values(t()) :: [String.t()]
  def secret_values(%__MODULE__{} = authority),
    do: SecretMaterial.secret_values(authority.secret_material)

  @spec credential_query_names(t()) :: [String.t()]
  def credential_query_names(%__MODULE__{} = authority) do
    authority |> query_params() |> Enum.map(&elem(&1, 0))
  end

  @spec rate_limit_scope(t()) :: String.t()
  def rate_limit_scope(%__MODULE__{materialization_request: request}),
    do: request.account.quota_scope_ref

  @spec account_namespace(t()) :: String.t()
  def account_namespace(%__MODULE__{materialization_request: request}),
    do: request.account.account_ref

  @spec refs(t()) :: map()
  def refs(%__MODULE__{} = authority) do
    request = authority.materialization_request
    account = request.account

    %{
      provider_ref: authority.provider_ref,
      provider_family: account.provider_family,
      provider_account_ref: account.account_ref,
      model_account_ref: authority.model_account_ref,
      tenant_id: account.tenant_id,
      connection_id: account.connection_id,
      endpoint_ref: request.endpoint_ref,
      quota_scope_ref: account.quota_scope_ref,
      credential_handle_ref: authority.credential_handle_ref,
      credential_lease_ref: request.lease_id,
      materialization_ref: request.materialization_ref,
      effect_ref: request.effect_ref,
      operation_ref: request.operation_ref,
      authority_ref: request.authority_ref,
      target_ref: request.target_ref,
      operation_policy_ref: authority.operation_policy_ref,
      redaction_ref: authority.redaction_ref,
      generation: account.generation,
      fence: account.fence,
      expires_at: request.expires_at
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  @spec validate_request_body!(term()) :: :ok
  def validate_request_body!(body) do
    case find_secret_bearing_key(body) do
      nil -> :ok
      key -> raise ArgumentError, "governed request body forbids credential field #{key}"
    end
  end

  @spec credential_request_key?(String.t()) :: boolean()
  def credential_request_key?(key) when is_binary(key) do
    normalize_name(key) in @credential_request_keys
  end

  defp validate!(%__MODULE__{} = authority) do
    request = MaterializationRequest.new!(authority.materialization_request)
    material = SecretMaterial.new!(authority.secret_material)
    account = request.account
    attrs = Map.from_struct(authority)

    Enum.each(
      [
        :base_url,
        :provider_ref,
        :model_account_ref,
        :credential_handle_ref,
        :operation_policy_ref
      ],
      &required_string!(attrs, &1)
    )

    mismatches =
      [
        {:materialization_ref, request.materialization_ref, material.materialization_ref},
        {:provider_family, account.provider_family, material.provider_family},
        {:account_ref, account.account_ref, material.account_ref},
        {:generation, account.generation, material.generation}
      ]
      |> Enum.filter(fn {_field, expected, actual} -> expected != actual end)

    if mismatches != [] do
      {field, _expected, _actual} = hd(mismatches)
      raise ArgumentError, "governed secret material #{field} binding does not match request"
    end

    headers = normalize_headers(authority.headers)
    validate_base_url!(authority.base_url)
    validate_public_headers!(headers, SecretMaterial.headers(material))

    %{
      authority
      | headers: headers,
        materialization_request: request,
        secret_material: material,
        credential_query_params: SecretMaterial.query_params(material)
    }
  end

  defp reject_legacy_secret_fields!(attrs) do
    case Enum.find(@legacy_secret_fields, &has_key?(attrs, &1)) do
      nil -> :ok
      key -> raise ArgumentError, "governed authority rejects legacy top-level #{key}"
    end
  end

  defp ensure_known_fields!(attrs) do
    allowed = MapSet.new(Enum.flat_map(@input_fields, &[&1, Atom.to_string(&1)]))

    unless Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, &1)) do
      raise ArgumentError, "governed authority contains unknown or unmanaged fields"
    end
  end

  defp validate_base_url!(base_url) do
    case URI.parse(base_url) do
      %URI{scheme: scheme, host: host, userinfo: nil, query: nil, fragment: nil}
      when scheme in ["http", "https", "ws", "wss"] and is_binary(host) and host != "" ->
        :ok

      _other ->
        raise ArgumentError, "governed authority requires an absolute credential-free base_url"
    end
  end

  defp validate_public_headers!(headers, credential_headers) do
    public_names = headers |> Map.keys() |> Enum.map(&normalize_name/1)
    credential_names = credential_headers |> Map.keys() |> Enum.map(&normalize_name/1)

    cond do
      Enum.any?(public_names, &(&1 in @credential_header_names)) ->
        raise ArgumentError, "governed authority headers cannot contain credentials"

      not MapSet.disjoint?(MapSet.new(public_names), MapSet.new(credential_names)) ->
        raise ArgumentError, "governed authority public and credential headers overlap"

      true ->
        :ok
    end
  end

  defp find_secret_bearing_key(term) when is_map(term) do
    Enum.find_value(term, fn {key, value} ->
      key = normalize_name(key)
      if key in @credential_request_keys, do: key, else: find_secret_bearing_key(value)
    end)
  end

  defp find_secret_bearing_key(term) when is_list(term),
    do: Enum.find_value(term, &find_secret_bearing_key/1)

  defp find_secret_bearing_key(_term), do: nil

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    if Enum.all?(headers, &match?({_, _}, &1)) do
      Map.new(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
    else
      raise ArgumentError, "governed authority headers must be key/value pairs"
    end
  end

  defp normalize_headers(_headers),
    do: raise(ArgumentError, "governed authority headers must be a map or keyword list")

  defp required_string!(attrs, key) do
    case optional_string(attrs, key) do
      value when is_binary(value) and value != "" -> value
      _other -> raise ArgumentError, "governed authority requires #{key}"
    end
  end

  defp optional_string(attrs, key) do
    case fetch_value(attrs, key) do
      nil -> nil
      value when is_binary(value) -> value
      value when is_atom(value) -> Atom.to_string(value)
      value -> to_string(value)
    end
  end

  defp normalize_attrs(%{__struct__: _module} = attrs), do: Map.from_struct(attrs)
  defp normalize_attrs(attrs), do: Map.new(attrs)

  defp has_key?(attrs, key),
    do: Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))

  defp fetch_value(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp normalize_name(name) do
    name
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> String.replace("-", "_")
  end
end

defimpl Inspect, for: Gemini.GovernedAuthority do
  import Inspect.Algebra

  def inspect(authority, opts) do
    rendered = %{
      base_url: authority.base_url,
      websocket_path: authority.websocket_path,
      refs: Gemini.GovernedAuthority.refs(authority),
      header_names: authority.headers |> Map.keys() |> Enum.sort(),
      credential_header_names:
        authority.secret_material
        |> Gemini.GovernedAuthority.SecretMaterial.headers()
        |> Map.keys()
        |> Enum.sort(),
      credential_query_names:
        authority |> Gemini.GovernedAuthority.credential_query_names() |> Enum.sort()
    }

    concat(["#Gemini.GovernedAuthority<", to_doc(rendered, opts), ">"])
  end
end

defimpl Jason.Encoder, for: Gemini.GovernedAuthority do
  def encode(_authority, _opts) do
    raise ArgumentError, "governed authority contains transient material and cannot be encoded"
  end
end
