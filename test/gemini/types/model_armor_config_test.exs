defmodule Gemini.Types.ModelArmorConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.ModelArmorConfig

  describe "new/1" do
    test "creates config with prompt template" do
      config =
        ModelArmorConfig.new(
          prompt_template_name: "projects/my-project/locations/us-central1/templates/t1"
        )

      assert config.prompt_template_name ==
               "projects/my-project/locations/us-central1/templates/t1"

      assert config.response_template_name == nil
    end

    test "creates config with both templates" do
      config =
        ModelArmorConfig.new(
          prompt_template_name: "projects/p/locations/l/templates/prompt",
          response_template_name: "projects/p/locations/l/templates/response"
        )

      assert config.prompt_template_name == "projects/p/locations/l/templates/prompt"
      assert config.response_template_name == "projects/p/locations/l/templates/response"
    end

    test "creates empty config" do
      config = ModelArmorConfig.new()

      assert config.prompt_template_name == nil
      assert config.response_template_name == nil
    end
  end

  describe "to_api/1" do
    test "converts to camelCase keys" do
      config = %ModelArmorConfig{
        prompt_template_name: "t1",
        response_template_name: "t2"
      }

      api = ModelArmorConfig.to_api(config)

      assert api["promptTemplateName"] == "t1"
      assert api["responseTemplateName"] == "t2"
    end

    test "excludes nil values" do
      config = %ModelArmorConfig{prompt_template_name: "t1"}

      api = ModelArmorConfig.to_api(config)

      assert Map.has_key?(api, "promptTemplateName")
      refute Map.has_key?(api, "responseTemplateName")
    end

    test "returns nil for nil input" do
      assert ModelArmorConfig.to_api(nil) == nil
    end
  end

  describe "from_api/1" do
    test "parses camelCase keys" do
      data = %{
        "promptTemplateName" => "template1",
        "responseTemplateName" => "template2"
      }

      config = ModelArmorConfig.from_api(data)

      assert config.prompt_template_name == "template1"
      assert config.response_template_name == "template2"
    end

    test "returns nil for nil input" do
      assert ModelArmorConfig.from_api(nil) == nil
    end

    test "passes through existing struct" do
      original = %ModelArmorConfig{prompt_template_name: "t1"}
      result = ModelArmorConfig.from_api(original)

      assert result == original
    end
  end

  describe "validate_exclusivity/3" do
    test "returns ok when model_armor_config is nil" do
      assert ModelArmorConfig.validate_exclusivity(nil, [%{}], :vertex_ai) == :ok
      assert ModelArmorConfig.validate_exclusivity(nil, [], :gemini) == :ok
    end

    test "returns error for Gemini API" do
      config = %ModelArmorConfig{prompt_template_name: "t1"}

      assert {:error, message} = ModelArmorConfig.validate_exclusivity(config, nil, :gemini)
      assert message =~ "only supported in Vertex AI"
    end

    test "returns error when both model_armor_config and safety_settings provided" do
      config = %ModelArmorConfig{prompt_template_name: "t1"}
      safety_settings = [%{category: :harm_category_hate_speech}]

      assert {:error, message} =
               ModelArmorConfig.validate_exclusivity(config, safety_settings, :vertex_ai)

      assert message =~ "mutually exclusive"
    end

    test "returns ok for Vertex AI with only model_armor_config" do
      config = %ModelArmorConfig{prompt_template_name: "t1"}

      assert ModelArmorConfig.validate_exclusivity(config, nil, :vertex_ai) == :ok
      assert ModelArmorConfig.validate_exclusivity(config, [], :vertex_ai) == :ok
    end
  end
end
