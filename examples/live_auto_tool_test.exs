#!/usr/bin/env elixir

# Live End-to-End Automatic Tool-Calling Test Script
# This script provides a comprehensive test of the automatic tool-calling feature
# using the real Gemini API with a practical Elixir module introspection tool.

Mix.install([
  {:gemini_ex, path: "."},
  {:altar, "~> 0.1.0"}
])

alias Gemini
alias Gemini.Tools
alias Altar.ADM
# alias Altar.ADM.ToolConfig  # Not available in current altar version

# Tool implementation module
defmodule LiveTestTools do
  @moduledoc """
  Real tool implementations for live testing automatic tool execution.
  """

  @doc """
  Gets comprehensive information about an Elixir module using built-in reflection.

  This tool demonstrates real Elixir code execution by introspecting modules
  and returning their documentation, functions, and metadata.
  """
  def get_elixir_module_info(args) do
    IO.puts("🔧 Tool called with args: #{inspect(args)}")

    module_name = case args do
      %{"module_name" => name} -> name
      %{module_name: name} -> name
      name when is_binary(name) -> name
      other ->
        IO.puts("🔧 Unexpected args format: #{inspect(other)}")
        "Enum"  # fallback
    end

    IO.puts("🔧 Using module_name: #{inspect(module_name)}")
    try do
      # Convert string to atom and ensure module is loaded
      module_atom = String.to_atom("Elixir.#{module_name}")

      case Code.ensure_loaded(module_atom) do
        {:module, ^module_atom} ->
          # Get module documentation
          {docstring, _metadata} = case Code.fetch_docs(module_atom) do
            {:docs_v1, _anno, _beam_language, _format, module_doc, _metadata, _docs} ->
              case module_doc do
                %{"en" => doc} -> {doc, %{}}
                doc when is_binary(doc) -> {doc, %{}}
                _ -> {"No documentation available", %{}}
              end
            _ -> {"No documentation available", %{}}
          end

          # Get public functions
          functions = try do
            module_atom.__info__(:functions)
            |> Enum.map(fn {name, arity} -> "#{name}/#{arity}" end)
            |> Enum.sort()
          rescue
            _ ->
              # Fallback: get exported functions from module_info
              try do
                module_atom.module_info(:exports)
                |> Enum.reject(fn {name, _arity} -> name == :module_info end)
                |> Enum.map(fn {name, arity} -> "#{name}/#{arity}" end)
                |> Enum.sort()
              rescue
                _ -> ["Unable to retrieve function list"]
              end
          end

          # Get module attributes if available
          attributes = try do
            behaviours = case module_atom.__info__(:attributes)[:behaviour] do
              nil -> []
              behaviours when is_list(behaviours) -> behaviours
              behaviour -> [behaviour]
            end

            # Convert compile info to JSON-safe format
            compile_info = module_atom.__info__(:compile)
            |> Keyword.take([:version, :time, :source])
            |> Enum.map(fn {key, value} ->
              {key, to_string(value)}
            end)
            |> Map.new()

            %{
              behaviours: behaviours,
              compile_info: compile_info
            }
          rescue
            _ -> %{behaviours: [], compile_info: %{}}
          end

          result = %{
            module: module_name,
            status: "found",
            docstring: String.slice(docstring, 0, 500) <> if(String.length(docstring) > 500, do: "...", else: ""),
            functions: Enum.take(functions, 20), # Limit to first 20 functions
            function_count: length(functions),
            attributes: attributes,
            introspection_timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
          IO.puts("🔧 Tool returning success result: #{inspect(result)}")
          result

        {:error, reason} ->
          result = %{
            module: module_name,
            status: "not_found",
            error: "Module could not be loaded: #{inspect(reason)}",
            suggestion: "Make sure the module name is correct (e.g., 'Enum', 'String', 'GenServer')",
            introspection_timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
          IO.puts("🔧 Tool returning error result: #{inspect(result)}")
          result
      end
    rescue
      error ->
        result = %{
          module: module_name,
          status: "error",
          error: "Exception during introspection: #{inspect(error)}",
          introspection_timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
        IO.puts("🔧 Tool returning exception result: #{inspect(result)}")
        result
    end
  end
end

# Main execution logic
defmodule LiveAutoToolTest do
  @moduledoc """
  Main test orchestrator for the live automatic tool-calling demonstration.
  """

  def run do
    print_header()

    case check_prerequisites() do
      :ok ->
        execute_test()
      {:error, message} ->
        IO.puts("❌ Prerequisites not met: #{message}")
        System.halt(1)
    end
  end

  defp print_header do
    IO.puts("""

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    Live Automatic Tool-Calling Test                          ║
    ║                                                                              ║
    ║  This script demonstrates end-to-end automatic tool execution using the     ║
    ║  real Gemini API with a practical Elixir module introspection tool.         ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    """)
  end

  defp check_prerequisites do
    IO.puts("🔍 Checking prerequisites...")

    case System.get_env("GEMINI_API_KEY") do
      nil ->
        {:error, """
        GEMINI_API_KEY environment variable is not set.

        Please set your API key:
          export GEMINI_API_KEY="your_api_key_here"

        You can get an API key from: https://makersuite.google.com/app/apikey
        """}

      key when byte_size(key) < 10 ->
        {:error, "GEMINI_API_KEY appears to be invalid (too short)"}

      _key ->
        IO.puts("✅ GEMINI_API_KEY found")
        :ok
    end
  end

  defp execute_test do
    IO.puts("\n📋 Test Steps:")
    IO.puts("1. Register the get_elixir_module_info tool")
    IO.puts("2. Send a prompt that requires tool usage")
    IO.puts("3. Let the system automatically execute the tool")
    IO.puts("4. Display the final synthesized response")

    IO.puts("\n" <> String.duplicate("=", 80))

    # Step 1: Register the tool
    IO.puts("\n🔧 Step 1: Registering the get_elixir_module_info tool...")

    {:ok, tool_declaration} = ADM.new_function_declaration(%{
      name: "get_elixir_module_info",
      description: """
      Gets comprehensive information about an Elixir module including its documentation,
      public functions, and metadata. Use this when the user asks about Elixir modules
      like Enum, String, GenServer, etc.
      """,
      parameters: %{
        type: "object",
        properties: %{
          module_name: %{
            type: "string",
            description: "The name of the Elixir module to introspect (e.g., 'Enum', 'String', 'GenServer')"
          }
        },
        required: ["module_name"]
      }
    })

    :ok = Tools.register(tool_declaration, &LiveTestTools.get_elixir_module_info/1)
    IO.puts("✅ Tool registered successfully")

    # Step 2: Define the test prompt
    IO.puts("\n💬 Step 2: Sending prompt that requires tool usage...")

    test_prompt = """
    I need detailed information about the Elixir Enum module. Please use the get_elixir_module_info tool
    to retrieve comprehensive information about the "Enum" module, including its documentation and functions.

    After getting the tool results, please explain:
    1. What is the main purpose and functionality of the Enum module?
    2. What are some of its most commonly used functions?
    3. Why is it useful for Elixir developers?

    You MUST use the get_elixir_module_info tool with module_name "Enum" to get this information.
    """

    IO.puts("📝 Prompt: #{String.slice(test_prompt, 0, 100)}...")

    # Step 3: Execute automatic tool calling
    IO.puts("\n🚀 Step 3: Executing automatic tool-calling with gemini-2.5-flash...")
    IO.puts("⏳ This may take a few moments as the system:")
    IO.puts("   • Sends the prompt to Gemini")
    IO.puts("   • Receives function call instructions")
    IO.puts("   • Executes the tool automatically")
    IO.puts("   • Sends results back to Gemini")
    IO.puts("   • Receives the final synthesized response")

    start_time = System.monotonic_time(:millisecond)

    # Debug: Show tool declaration structure
    IO.puts("🔍 Debug: Tool declaration structure:")
    IO.inspect(tool_declaration, limit: :infinity, pretty: true)

    result = Gemini.generate_content_with_auto_tools(
      test_prompt,
      tools: [tool_declaration],
      model: "gemini-2.5-flash",
      temperature: 0.1,
      turn_limit: 10
    )

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Step 4: Display results
    IO.puts("\n📊 Step 4: Processing results...")
    IO.puts("⏱️  Total execution time: #{duration}ms")

    case result do
      {:ok, response} ->
        case Gemini.extract_text(response) do
          {:ok, text} ->
            IO.puts("\n" <> String.duplicate("=", 80))
            IO.puts("🎉 SUCCESS! Final Response from Gemini:")
            IO.puts(String.duplicate("=", 80))
            IO.puts(text)
            IO.puts(String.duplicate("=", 80))

            IO.puts("\n✅ Test completed successfully!")
            IO.puts("🔍 The tool was automatically executed and the response was synthesized.")

          {:error, extract_error} ->
            IO.puts("\n⚠️  Response received but text extraction failed:")
            IO.puts("Error: #{extract_error}")
            IO.puts("Raw response structure:")
            IO.inspect(response, limit: :infinity, pretty: true)
        end

      {:error, error} ->
        IO.puts("\n❌ Test failed with error:")
        IO.puts("#{inspect(error)}")

        case error do
          %{type: :authentication} ->
            IO.puts("\n💡 This looks like an authentication error.")
            IO.puts("Please verify your GEMINI_API_KEY is correct.")

          %{type: :rate_limit} ->
            IO.puts("\n💡 Rate limit exceeded. Please wait and try again.")

          %{type: :turn_limit_exceeded} ->
            IO.puts("\n💡 The tool-calling loop exceeded the maximum number of turns.")
            IO.puts("This might indicate an issue with the tool implementation.")

          _ ->
            IO.puts("\n💡 For troubleshooting:")
            IO.puts("• Verify your internet connection")
            IO.puts("• Check that your API key has sufficient quota")
            IO.puts("• Ensure the Gemini API service is available")
        end
    end

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🏁 Live Automatic Tool-Calling Test Complete")
    IO.puts(String.duplicate("=", 80))
  end
end

# Execute the test
LiveAutoToolTest.run()
