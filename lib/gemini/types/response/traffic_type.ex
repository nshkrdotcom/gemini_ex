defmodule Gemini.Types.Response.TrafficType do
  @moduledoc """
  Traffic type for API requests (billing classification).
  """

  @type t :: :traffic_type_unspecified | :on_demand | :provisioned_throughput

  @doc """
  Parse traffic type from API string.
  """
  @spec from_api(String.t() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api("ON_DEMAND"), do: :on_demand
  def from_api("PROVISIONED_THROUGHPUT"), do: :provisioned_throughput
  def from_api("TRAFFIC_TYPE_UNSPECIFIED"), do: :traffic_type_unspecified
  def from_api(_), do: :traffic_type_unspecified

  @doc """
  Convert traffic type atom to API string.
  """
  @spec to_api(t() | atom() | nil) :: String.t() | nil
  def to_api(nil), do: nil
  def to_api(:on_demand), do: "ON_DEMAND"
  def to_api(:provisioned_throughput), do: "PROVISIONED_THROUGHPUT"
  def to_api(:traffic_type_unspecified), do: "TRAFFIC_TYPE_UNSPECIFIED"
  def to_api(_), do: "TRAFFIC_TYPE_UNSPECIFIED"
end
