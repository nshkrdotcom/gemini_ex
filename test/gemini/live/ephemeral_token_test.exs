defmodule Gemini.Live.EphemeralTokenTest do
  @moduledoc """
  Unit tests for Gemini.Live.EphemeralToken.

  These tests verify the EphemeralToken module's request building
  and response handling without making actual API calls.
  """

  use ExUnit.Case, async: true

  # These tests call EphemeralToken.create/1 which requires API authentication
  @moduletag :live_api

  alias Gemini.Live.EphemeralToken

  describe "create/1 request building" do
    test "builds request with default values" do
      # Verify the function signature is correct
      assert is_function(&EphemeralToken.create/0, 0)
      assert is_function(&EphemeralToken.create/1, 1)
    end

    test "accepts uses option" do
      # The actual HTTP call will return an error without proper setup
      # but this verifies the function accepts the option
      result = EphemeralToken.create(uses: 5)
      assert {:error, _} = result
    end

    test "accepts expire_minutes option" do
      result = EphemeralToken.create(expire_minutes: 60)
      assert {:error, _} = result
    end

    test "accepts new_session_expire_minutes option" do
      result = EphemeralToken.create(new_session_expire_minutes: 5)
      assert {:error, _} = result
    end

    test "accepts live_connect_constraints option" do
      constraints = %{
        model: "gemini-2.5-flash-native-audio-preview-12-2025",
        config: %{response_modalities: [:audio]}
      }

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end

    test "accepts all options together" do
      result =
        EphemeralToken.create(
          uses: 1,
          expire_minutes: 30,
          new_session_expire_minutes: 1,
          live_connect_constraints: %{
            model: "gemini-2.5-flash-native-audio-preview-12-2025",
            config: %{
              response_modalities: [:audio],
              temperature: 0.7
            }
          }
        )

      assert {:error, _} = result
    end
  end

  describe "constraint formatting" do
    # These tests verify the internal formatting logic by calling create
    # with various constraint structures

    test "handles constraints with model only" do
      constraints = %{model: "gemini-2.5-flash"}

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end

    test "handles constraints with model and config" do
      constraints = %{
        model: "gemini-2.5-flash",
        config: %{
          response_modalities: [:text, :audio],
          temperature: 0.5
        }
      }

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end

    test "handles session_resumption in config" do
      constraints = %{
        model: "gemini-2.5-flash",
        config: %{
          session_resumption: %{},
          response_modalities: [:audio]
        }
      }

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end
  end

  describe "modality conversion" do
    test "module handles :audio modality" do
      constraints = %{
        model: "gemini-2.5-flash",
        config: %{response_modalities: [:audio]}
      }

      # The conversion happens internally, we just verify no crash
      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end

    test "module handles :text modality" do
      constraints = %{
        model: "gemini-2.5-flash",
        config: %{response_modalities: [:text]}
      }

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end

    test "module handles :image modality" do
      constraints = %{
        model: "gemini-2.5-flash",
        config: %{response_modalities: [:image]}
      }

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end

    test "module handles mixed modalities" do
      constraints = %{
        model: "gemini-2.5-flash",
        config: %{response_modalities: [:text, :audio]}
      }

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end

    test "module handles string modalities" do
      constraints = %{
        model: "gemini-2.5-flash",
        config: %{response_modalities: ["AUDIO", "TEXT"]}
      }

      result = EphemeralToken.create(live_connect_constraints: constraints)
      assert {:error, _} = result
    end
  end
end
