# Function Calling (Tool Use) Example
# Run with: mix run examples/05_function_calling.exs
#
# Demonstrates:
# - Defining function declarations
# - Registering tool implementations
# - Automatic tool execution loop
# - Multi-tool conversations

defmodule FunctionCallingExample do
  alias Gemini.Tools
  alias Altar.ADM

  def run do
    print_header("FUNCTION CALLING (TOOL USE)")

    check_auth!()

    register_tools()
    demo_weather_tool()
    demo_calculator_tool()
    demo_multi_tool()

    print_footer()
  end

  # ============================================================
  # Tool Implementations
  # ============================================================
  defmodule ToolImplementations do
    def get_weather(%{"location" => location}) do
      # Simulated weather API
      %{
        location: location,
        temperature_celsius: Enum.random(15..30),
        condition: Enum.random(["sunny", "cloudy", "rainy", "partly cloudy"]),
        humidity_percent: Enum.random(30..80),
        wind_speed_kmh: Enum.random(5..25)
      }
    end

    def calculate(%{"operation" => op, "a" => a, "b" => b}) do
      result =
        case op do
          "add" -> a + b
          "subtract" -> a - b
          "multiply" -> a * b
          "divide" when b != 0 -> Float.round(a / b, 4)
          "divide" -> "Error: Division by zero"
          "power" -> :math.pow(a, b)
          _ -> "Error: Unknown operation '#{op}'"
        end

      %{operation: op, a: a, b: b, result: result}
    end

    def get_stock_price(%{"symbol" => symbol}) do
      # Simulated stock API
      prices = %{
        "AAPL" => 178.50,
        "GOOGL" => 141.25,
        "MSFT" => 378.90,
        "AMZN" => 178.35
      }

      case Map.get(prices, String.upcase(symbol)) do
        nil -> %{symbol: symbol, error: "Symbol not found"}
        price -> %{symbol: String.upcase(symbol), price: price, currency: "USD"}
      end
    end
  end

  # ============================================================
  # Tool Registration
  # ============================================================
  defp register_tools do
    print_section("Registering Tools")

    # Weather Tool
    {:ok, weather_decl} =
      ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Gets current weather information for a specified location",
        parameters: %{
          type: "object",
          properties: %{
            location: %{
              type: "string",
              description: "City name (e.g., 'San Francisco', 'London', 'Tokyo')"
            }
          },
          required: ["location"]
        }
      })

    :ok = Tools.register(weather_decl, &ToolImplementations.get_weather/1)
    IO.puts("  [+] Registered: get_weather")

    # Calculator Tool
    {:ok, calc_decl} =
      ADM.new_function_declaration(%{
        name: "calculate",
        description: "Performs mathematical calculations",
        parameters: %{
          type: "object",
          properties: %{
            operation: %{
              type: "string",
              enum: ["add", "subtract", "multiply", "divide", "power"],
              description: "The mathematical operation"
            },
            a: %{type: "number", description: "First operand"},
            b: %{type: "number", description: "Second operand"}
          },
          required: ["operation", "a", "b"]
        }
      })

    :ok = Tools.register(calc_decl, &ToolImplementations.calculate/1)
    IO.puts("  [+] Registered: calculate")

    # Stock Price Tool
    {:ok, stock_decl} =
      ADM.new_function_declaration(%{
        name: "get_stock_price",
        description: "Gets current stock price for a symbol",
        parameters: %{
          type: "object",
          properties: %{
            symbol: %{
              type: "string",
              description: "Stock ticker symbol (e.g., AAPL, GOOGL)"
            }
          },
          required: ["symbol"]
        }
      })

    :ok = Tools.register(stock_decl, &ToolImplementations.get_stock_price/1)
    IO.puts("  [+] Registered: get_stock_price")

    IO.puts("")
    IO.puts("[OK] All tools registered")
    IO.puts("")

    # Return declarations for use in API calls
    [weather_decl, calc_decl, stock_decl]
  end

  # ============================================================
  # Demo 1: Weather Tool
  # ============================================================
  defp demo_weather_tool do
    print_section("1. Weather Tool Demo")

    prompt = "What's the weather like in Tokyo right now?"

    IO.puts("USER PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    # Get the weather declaration
    {:ok, weather_decl} =
      ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Gets current weather information for a specified location",
        parameters: %{
          type: "object",
          properties: %{
            location: %{type: "string", description: "City name"}
          },
          required: ["location"]
        }
      })

    IO.puts("Calling Gemini with auto tool execution...")
    IO.puts("")

    case Gemini.generate_content_with_auto_tools(prompt,
           tools: [weather_decl],
           turn_limit: 3
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("FINAL RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")
        IO.puts("[OK] Weather tool executed automatically!")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Calculator Tool
  # ============================================================
  defp demo_calculator_tool do
    print_section("2. Calculator Tool Demo")

    prompt = "What is 123 multiplied by 456, and then divide the result by 7?"

    IO.puts("USER PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    {:ok, calc_decl} =
      ADM.new_function_declaration(%{
        name: "calculate",
        description: "Performs mathematical calculations",
        parameters: %{
          type: "object",
          properties: %{
            operation: %{type: "string", enum: ["add", "subtract", "multiply", "divide", "power"]},
            a: %{type: "number"},
            b: %{type: "number"}
          },
          required: ["operation", "a", "b"]
        }
      })

    IO.puts("Calling Gemini with auto tool execution...")
    IO.puts("")

    case Gemini.generate_content_with_auto_tools(prompt,
           tools: [calc_decl],
           turn_limit: 5
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("FINAL RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")
        IO.puts("[OK] Calculator tool executed (possibly multiple times)!")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 3: Multi-Tool Interaction
  # ============================================================
  defp demo_multi_tool do
    print_section("3. Multi-Tool Interaction Demo")

    prompt =
      "I'm planning a trip. What's the weather in San Francisco? Also, if a hotel costs $250/night for 5 nights, what's the total?"

    IO.puts("USER PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    # Define both tools
    {:ok, weather_decl} =
      ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Gets current weather",
        parameters: %{
          type: "object",
          properties: %{location: %{type: "string"}},
          required: ["location"]
        }
      })

    {:ok, calc_decl} =
      ADM.new_function_declaration(%{
        name: "calculate",
        description: "Math calculations",
        parameters: %{
          type: "object",
          properties: %{
            operation: %{type: "string"},
            a: %{type: "number"},
            b: %{type: "number"}
          },
          required: ["operation", "a", "b"]
        }
      })

    IO.puts("Available tools: get_weather, calculate")
    IO.puts("Calling Gemini with auto tool execution...")
    IO.puts("")

    case Gemini.generate_content_with_auto_tools(prompt,
           tools: [weather_decl, calc_decl],
           turn_limit: 5
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("FINAL RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")
        IO.puts("[OK] Multiple tools executed in single conversation!")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Helper Functions
  # ============================================================
  defp check_auth! do
    cond do
      System.get_env("GEMINI_API_KEY") ->
        key = System.get_env("GEMINI_API_KEY")
        masked = String.slice(key, 0, 4) <> "..." <> String.slice(key, -4, 4)
        IO.puts("AUTH: Using Gemini API Key (#{masked})")
        IO.puts("")

      System.get_env("VERTEX_JSON_FILE") || System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ->
        IO.puts("AUTH: Using Vertex AI / Application Default Credentials")
        IO.puts("")

      true ->
        IO.puts("[ERROR] No authentication configured!")
        IO.puts("Set GEMINI_API_KEY or VERTEX_JSON_FILE environment variable.")
        System.halt(1)
    end
  end

  defp print_header(title) do
    IO.puts("")
    IO.puts(String.duplicate("=", 70))
    IO.puts("  #{title}")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end

  defp print_section(title) do
    IO.puts(String.duplicate("-", 70))
    IO.puts(title)
    IO.puts(String.duplicate("-", 70))
    IO.puts("")
  end

  defp print_footer do
    IO.puts(String.duplicate("=", 70))
    IO.puts("  EXAMPLE COMPLETE")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end
end

FunctionCallingExample.run()
