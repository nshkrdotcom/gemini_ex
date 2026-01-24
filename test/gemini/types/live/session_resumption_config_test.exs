defmodule Gemini.Types.Live.SessionResumptionConfigTest do
  @moduledoc """
  Tests for SessionResumptionConfig to verify session resumption handle serialization.
  """

  use ExUnit.Case, async: true

  alias Gemini.Types.Live.SessionResumptionConfig

  describe "to_api/1" do
    test "returns nil for nil input" do
      assert SessionResumptionConfig.to_api(nil) == nil
    end

    test "returns empty map for empty struct" do
      config = %SessionResumptionConfig{}
      assert SessionResumptionConfig.to_api(config) == %{}
    end

    test "returns empty map for empty map input" do
      assert SessionResumptionConfig.to_api(%{}) == %{}
    end

    test "includes handle when provided in struct" do
      config = %SessionResumptionConfig{handle: "test-handle-123"}
      result = SessionResumptionConfig.to_api(config)

      assert result == %{"handle" => "test-handle-123"}
    end

    test "includes handle when provided in map" do
      config = %{handle: "test-handle-456"}
      result = SessionResumptionConfig.to_api(config)

      assert result == %{"handle" => "test-handle-456"}
    end

    test "includes transparent when provided in struct" do
      config = %SessionResumptionConfig{transparent: true}
      result = SessionResumptionConfig.to_api(config)

      assert result == %{"transparent" => true}
    end

    test "includes both handle and transparent when provided" do
      config = %SessionResumptionConfig{handle: "resume-handle", transparent: true}
      result = SessionResumptionConfig.to_api(config)

      assert result == %{"handle" => "resume-handle", "transparent" => true}
    end

    test "includes both handle and transparent from map" do
      config = %{handle: "resume-handle", transparent: true}
      result = SessionResumptionConfig.to_api(config)

      assert result == %{"handle" => "resume-handle", "transparent" => true}
    end

    test "includes both handle and transparent from string-key map" do
      config = %{"handle" => "resume-handle", "transparent" => false}
      result = SessionResumptionConfig.to_api(config)

      assert result == %{"handle" => "resume-handle", "transparent" => false}
    end
  end

  describe "new/1" do
    test "creates config with default nil values" do
      config = SessionResumptionConfig.new()
      assert config.handle == nil
      assert config.transparent == nil
    end

    test "creates config with handle option" do
      config = SessionResumptionConfig.new(handle: "my-handle")
      assert config.handle == "my-handle"
      assert config.transparent == nil
    end

    test "creates config with transparent option" do
      config = SessionResumptionConfig.new(transparent: true)
      assert config.handle == nil
      assert config.transparent == true
    end

    test "creates config with both options" do
      config = SessionResumptionConfig.new(handle: "my-handle", transparent: true)
      assert config.handle == "my-handle"
      assert config.transparent == true
    end
  end

  describe "from_api/1" do
    test "returns nil for nil input" do
      assert SessionResumptionConfig.from_api(nil) == nil
    end

    test "parses handle from API response" do
      data = %{"handle" => "api-handle-123"}
      config = SessionResumptionConfig.from_api(data)

      assert config.handle == "api-handle-123"
      assert config.transparent == nil
    end

    test "parses transparent from API response" do
      data = %{"transparent" => true}
      config = SessionResumptionConfig.from_api(data)

      assert config.handle == nil
      assert config.transparent == true
    end

    test "parses both fields from API response" do
      data = %{"handle" => "api-handle", "transparent" => true}
      config = SessionResumptionConfig.from_api(data)

      assert config.handle == "api-handle"
      assert config.transparent == true
    end
  end
end
