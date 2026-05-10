defmodule Gemini.Env do
  @moduledoc false

  @app :gemini_ex
  @key :env

  @spec all(map() | keyword()) :: %{optional(String.t()) => String.t()}
  def all(overrides \\ %{}) do
    configured()
    |> Map.merge(normalize(overrides))
  end

  @spec get(String.t(), map() | keyword() | nil) :: String.t() | nil
  def get(key, env \\ nil)
  def get(key, nil) when is_binary(key), do: Map.get(all(), key)
  def get(key, env) when is_binary(key), do: Map.get(all(env), key)

  @spec fetch!(String.t(), map() | keyword() | nil) :: String.t()
  def fetch!(key, env \\ nil) when is_binary(key) do
    case get(key, env) do
      nil -> raise System.EnvError, env: key
      value -> value
    end
  end

  @spec put(String.t(), term()) :: :ok
  def put(key, value) when is_binary(key) do
    Application.put_env(@app, @key, Map.put(configured(), key, to_string(value)))
  end

  @spec delete(String.t()) :: :ok
  def delete(key) when is_binary(key) do
    Application.put_env(@app, @key, Map.delete(configured(), key))
  end

  @spec present?(String.t()) :: boolean()
  def present?(key) when is_binary(key) do
    case get(key) do
      value when is_binary(value) and value != "" -> true
      _other -> false
    end
  end

  @spec configured() :: %{optional(String.t()) => String.t()}
  def configured do
    @app
    |> Application.get_env(@key, %{})
    |> normalize()
  end

  @spec normalize(map() | keyword() | nil) :: %{optional(String.t()) => String.t()}
  def normalize(env) when is_map(env) do
    env
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  def normalize(env) when is_list(env) do
    env
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  def normalize(_env), do: %{}
end
