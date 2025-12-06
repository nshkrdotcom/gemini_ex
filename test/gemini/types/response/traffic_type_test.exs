defmodule Gemini.Types.Response.TrafficTypeTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.TrafficType

  describe "from_api/1" do
    test "maps known values" do
      assert TrafficType.from_api("ON_DEMAND") == :on_demand
      assert TrafficType.from_api("PROVISIONED_THROUGHPUT") == :provisioned_throughput
    end

    test "returns unspecified for unknown" do
      assert TrafficType.from_api("SOMETHING_ELSE") == :traffic_type_unspecified
      assert TrafficType.from_api(nil) == nil
    end
  end

  describe "to_api/1" do
    test "converts atoms to API strings" do
      assert TrafficType.to_api(:on_demand) == "ON_DEMAND"
      assert TrafficType.to_api(:provisioned_throughput) == "PROVISIONED_THROUGHPUT"
      assert TrafficType.to_api(:traffic_type_unspecified) == "TRAFFIC_TYPE_UNSPECIFIED"
    end

    test "defaults to unspecified for unknown atoms" do
      assert TrafficType.to_api(:unexpected) == "TRAFFIC_TYPE_UNSPECIFIED"
    end
  end
end
