#!/usr/bin/env elixir

# Simple Live Tool-Calling Test
# A minimal test to verify automatic tool execution works

alias Gemini
alias Gemini.Tools
alias Altar.ADM
# alias Altar.ADM.ToolConfig

# Simple tool that just returns basic info
defmodule SimpleTools do
  def get_current_time(%{}) do
    %{
      current_time: DateTime.utc_now() |> DateTime.to_iso8601(),
      timezone: "UTC",
      timestamp: System.system_time(:second)
    }
  end
end

# Check API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("❌ GEMINI_API_KEY not set")
    System.halt(1)

  _key ->
    IO.puts("✅ API key found")
end

# Register simple tool
{:ok, tool_declaration} =
  ADM.new_function_declaration(%{
    name: "get_current_time",
    description: "Gets the current UTC time and timestamp",
    parameters: %{
      type: "object",
      properties: %{},
      required: []
    }
  })

:ok = Tools.register(tool_declaration, &SimpleTools.get_current_time/1)
IO.puts("✅ Tool registered")

# Test prompt that strongly encourages tool usage
prompt = """
What time is it right now? I need you to use the get_current_time tool to get the exact current time.
You MUST call the get_current_time function to answer this question.
"""

IO.puts("🚀 Testing automatic tool calling...")

result =
  Gemini.generate_content_with_auto_tools(
    prompt,
    tools: [tool_declaration],
    model: "gemini-flash-lite-latest",
    temperature: 0.1,
    turn_limit: 3
  )

case result do
  {:ok, response} ->
    case Gemini.extract_text(response) do
      {:ok, text} ->
        IO.puts("\n🎉 SUCCESS!")
        IO.puts("Response: #{text}")

      {:error, error} ->
        IO.puts("❌ Text extraction failed: #{error}")
    end

  {:error, error} ->
    IO.puts("❌ Tool calling failed: #{inspect(error)}")
end
