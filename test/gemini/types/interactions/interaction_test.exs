defmodule Gemini.Types.Interactions.InteractionTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Interactions.Interaction

  describe "from_api/1" do
    test "does not include object field" do
      interaction =
        Interaction.from_api(%{
          "id" => "int_123",
          "status" => "completed",
          "object" => "interaction"
        })

      refute Map.has_key?(interaction, :object)
    end
  end

  describe "to_api/1" do
    test "does not serialize object field" do
      interaction = %Interaction{id: "int_123", status: "completed"}

      refute Map.has_key?(Interaction.to_api(interaction), "object")
    end
  end
end
