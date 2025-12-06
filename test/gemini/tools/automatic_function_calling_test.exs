defmodule Gemini.Tools.AutomaticFunctionCallingTest do
  @moduledoc """
  Tests for the AutomaticFunctionCalling module that implements the AFC loop.
  """

  use ExUnit.Case, async: true

  alias Gemini.Tools.AutomaticFunctionCalling, as: AFC
  alias Altar.ADM.FunctionCall

  describe "config/1" do
    test "creates default config" do
      config = AFC.config()

      assert config.max_calls == 10
      assert config.ignore_call_history == false
      assert config.enabled == true
    end

    test "creates config with custom max_calls" do
      config = AFC.config(max_calls: 5)

      assert config.max_calls == 5
    end

    test "creates disabled config" do
      config = AFC.config(enabled: false)

      assert config.enabled == false
    end
  end

  describe "extract_function_calls/1" do
    test "extracts function calls from response with functionCall parts" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "functionCall" => %{
                    "name" => "get_weather",
                    "args" => %{"location" => "NYC"}
                  }
                }
              ]
            }
          }
        ]
      }

      calls = AFC.extract_function_calls(response)

      assert length(calls) == 1
      assert hd(calls).name == "get_weather"
      assert hd(calls).args == %{"location" => "NYC"}
    end

    test "extracts multiple function calls" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{"functionCall" => %{"name" => "func1", "args" => %{}}},
                %{"functionCall" => %{"name" => "func2", "args" => %{}}}
              ]
            }
          }
        ]
      }

      calls = AFC.extract_function_calls(response)

      assert length(calls) == 2
      assert Enum.map(calls, & &1.name) == ["func1", "func2"]
    end

    test "returns empty list when no function calls" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{"text" => "Hello, world!"}
              ]
            }
          }
        ]
      }

      calls = AFC.extract_function_calls(response)

      assert calls == []
    end

    test "handles GenerateContentResponse struct" do
      response = %Gemini.Types.Response.GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [
                %{
                  "functionCall" => %{
                    "name" => "search",
                    "args" => %{"query" => "test"}
                  }
                }
              ]
            }
          }
        ]
      }

      calls = AFC.extract_function_calls(response)

      assert length(calls) == 1
      assert hd(calls).name == "search"
    end
  end

  describe "has_function_calls?/1" do
    test "returns true when response has function calls" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"functionCall" => %{"name" => "test", "args" => %{}}}]
            }
          }
        ]
      }

      assert AFC.has_function_calls?(response) == true
    end

    test "returns false when response has no function calls" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"text" => "Just text"}]
            }
          }
        ]
      }

      assert AFC.has_function_calls?(response) == false
    end
  end

  describe "build_function_response_content/2" do
    test "builds content with function responses" do
      {:ok, call1} = FunctionCall.new(call_id: "1", name: "func1", args: %{})
      {:ok, call2} = FunctionCall.new(call_id: "2", name: "func2", args: %{})

      calls = [call1, call2]
      results = [{:ok, "result1"}, {:ok, "result2"}]

      content = AFC.build_function_response_content(calls, results)

      assert content.role == "function"
      assert length(content.parts) == 2
    end
  end

  describe "should_continue?/3" do
    test "returns false when config is disabled" do
      config = AFC.config(enabled: false)

      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"functionCall" => %{"name" => "test", "args" => %{}}}]
            }
          }
        ]
      }

      assert AFC.should_continue?(response, config, 0) == false
    end

    test "returns false when max_calls reached" do
      config = AFC.config(max_calls: 3)

      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"functionCall" => %{"name" => "test", "args" => %{}}}]
            }
          }
        ]
      }

      assert AFC.should_continue?(response, config, 3) == false
    end

    test "returns true when function calls present and under limit" do
      config = AFC.config(max_calls: 10)

      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"functionCall" => %{"name" => "test", "args" => %{}}}]
            }
          }
        ]
      }

      assert AFC.should_continue?(response, config, 0) == true
    end

    test "returns false when no function calls" do
      config = AFC.config()

      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"text" => "No calls here"}]
            }
          }
        ]
      }

      assert AFC.should_continue?(response, config, 0) == false
    end
  end

  describe "track_history/2" do
    test "appends call to history" do
      {:ok, call} = FunctionCall.new(call_id: "1", name: "test", args: %{})
      history = []

      new_history = AFC.track_history(history, [call])

      assert length(new_history) == 1
      assert hd(new_history).name == "test"
    end

    test "accumulates multiple calls" do
      {:ok, call1} = FunctionCall.new(call_id: "1", name: "func1", args: %{})
      {:ok, call2} = FunctionCall.new(call_id: "2", name: "func2", args: %{})

      history =
        []
        |> AFC.track_history([call1])
        |> AFC.track_history([call2])

      assert length(history) == 2
    end
  end
end
