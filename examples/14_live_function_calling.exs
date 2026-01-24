#!/usr/bin/env elixir
# Live API Function Calling Demo (with Telemetry)
# Run with: mix run examples/14_live_function_calling.exs
#
# Demonstrates tool/function calling with the Live API including:
# - Defining function declarations
# - Handling tool call requests
# - Sending tool responses back
# - Telemetry observability
#
# MODEL NOTE: This example uses the canonical TEXT model from Google's docs:
#   gemini-live-2.5-flash-preview with response_modalities: ["TEXT"]
#
# If this model is not yet available, see examples/12_live_audio_streaming.exs
# for a working AUDIO example using flash_2_5_native_audio_preview_12_2025.

alias Gemini.Live.Models
alias Gemini.Live.Session

IO.puts("=== Live API Function Calling with Telemetry ===\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("Error: GEMINI_API_KEY environment variable not set")
    IO.puts("Please set your API key: export GEMINI_API_KEY=your_key")
    System.halt(1)

  _ ->
    IO.puts("[OK] API key found")
end

# Setup telemetry handlers to observe Live API events
:telemetry.attach_many(
  "live-api-telemetry-demo",
  [
    [:gemini, :live, :session, :init],
    [:gemini, :live, :session, :ready],
    [:gemini, :live, :session, :message, :sent],
    [:gemini, :live, :session, :message, :received],
    [:gemini, :live, :session, :tool_call],
    [:gemini, :live, :session, :close],
    [:gemini, :live, :session, :error],
    [:gemini, :client, :websocket, :connect, :start],
    [:gemini, :client, :websocket, :connect, :stop],
    [:gemini, :client, :websocket, :send]
  ],
  fn event, measurements, metadata, _config ->
    event_name = Enum.join(event, ".")
    IO.puts("[Telemetry] #{event_name}")

    if map_size(measurements) > 0 do
      IO.puts("  Measurements: #{inspect(measurements)}")
    end

    relevant_meta = Map.drop(metadata, [:system_time])

    if map_size(relevant_meta) > 0 do
      IO.puts("  Metadata: #{inspect(relevant_meta)}")
    end
  end,
  nil
)

IO.puts("[OK] Telemetry handlers attached\n")

# Define tools
tools = [
  %{
    function_declarations: [
      %{
        name: "get_stock_price",
        description: "Get the current stock price for a given symbol",
        parameters: %{
          type: "object",
          properties: %{
            symbol: %{
              type: "string",
              description: "Stock ticker symbol (e.g., 'AAPL', 'GOOGL')"
            }
          },
          required: ["symbol"]
        }
      },
      %{
        name: "search_products",
        description: "Search for products in a catalog",
        parameters: %{
          type: "object",
          properties: %{
            query: %{
              type: "string",
              description: "Search query"
            },
            max_results: %{
              type: "integer",
              description: "Maximum number of results to return"
            }
          },
          required: ["query"]
        }
      }
    ]
  }
]

# Mock implementations
defmodule DemoTools do
  def get_stock_price(symbol) do
    prices = %{
      "AAPL" => %{price: 178.50, currency: "USD", change: "+1.25"},
      "GOOGL" => %{price: 141.20, currency: "USD", change: "-0.80"},
      "MSFT" => %{price: 378.90, currency: "USD", change: "+2.10"},
      "AMZN" => %{price: 178.25, currency: "USD", change: "+0.50"}
    }

    case Map.get(prices, String.upcase(symbol)) do
      nil -> %{error: "Symbol not found", symbol: symbol}
      data -> Map.put(data, :symbol, String.upcase(symbol))
    end
  end

  def search_products(query, max_results \\ 3) do
    products = [
      %{id: "P001", name: "Wireless Headphones", price: 79.99, rating: 4.5},
      %{id: "P002", name: "Mechanical Keyboard", price: 129.99, rating: 4.8},
      %{id: "P003", name: "USB-C Hub", price: 49.99, rating: 4.2},
      %{id: "P004", name: "Webcam HD", price: 89.99, rating: 4.3},
      %{id: "P005", name: "Monitor Stand", price: 34.99, rating: 4.6}
    ]

    results =
      products
      |> Enum.filter(fn p ->
        String.contains?(String.downcase(p.name), String.downcase(query))
      end)
      |> Enum.take(max_results)

    %{query: query, results: results, total_found: length(results)}
  end
end

# Tool call handler
tool_handler = fn %{function_calls: calls} ->
  IO.puts("\n[Executing #{length(calls)} tool call(s)]")

  responses =
    Enum.map(calls, fn call ->
      IO.puts("  Function: #{call.name}")
      IO.puts("  Args: #{inspect(call.args)}")

      result =
        case call.name do
          "get_stock_price" ->
            symbol = call.args["symbol"] || call.args[:symbol] || "UNKNOWN"
            DemoTools.get_stock_price(symbol)

          "search_products" ->
            args = call.args
            query = args["query"] || args[:query] || ""
            max = args["max_results"] || args[:max_results] || 3
            DemoTools.search_products(query, max)

          _ ->
            %{error: "Unknown function: #{call.name}"}
        end

      IO.puts("  Result: #{inspect(result)}")

      %{
        id: call.id,
        name: call.name,
        response: result
      }
    end)

  IO.puts("[Returning tool responses]")
  {:tool_response, responses}
end

# Message handler
message_handler = fn
  %{setup_complete: sc} when not is_nil(sc) ->
    IO.puts("[Setup complete]")

  %{server_content: content} when not is_nil(content) ->
    if text = Gemini.Types.Live.ServerContent.extract_text(content) do
      IO.write(text)
    end

    if content.turn_complete do
      IO.puts("\n[Turn complete]")
    end

  %{tool_call: tc} when not is_nil(tc) ->
    # Handled by on_tool_call callback
    :ok

  %{tool_call_cancellation: tc_cancel} when not is_nil(tc_cancel) ->
    IO.puts("[Tool calls cancelled: #{inspect(tc_cancel)}]")

  _ ->
    :ok
end

IO.puts("Starting Live API session with tools...")

live_model = Models.resolve(:text)
IO.puts("[Using model: #{live_model}]")

# Start session
{:ok, session} =
  Session.start_link(
    model: live_model,
    auth: :gemini,
    generation_config: %{response_modalities: ["TEXT"]},
    tools: tools,
    on_message: message_handler,
    on_tool_call: tool_handler,
    on_tool_call_cancellation: fn ids -> IO.puts("[Cancelled: #{inspect(ids)}]") end,
    on_error: fn err -> IO.puts("\n[Error: #{inspect(err)}]") end
  )

IO.puts("[OK] Session started")

# Connect
IO.puts("Connecting...")

case Session.connect(session) do
  :ok ->
    IO.puts("[OK] Connected\n")

  {:error, reason} ->
    IO.puts("[Error] Connection failed: #{inspect(reason)}")
    System.halt(1)
end

Process.sleep(500)

# Test queries
queries = [
  "What's the current price of Apple stock?",
  "Search for headphones in our catalog.",
  "Compare the stock prices of Google and Microsoft."
]

for {query, index} <- Enum.with_index(queries, 1) do
  IO.puts("\n--- Query #{index} ---")
  IO.puts(">>> #{query}\n")
  :ok = Session.send_client_content(session, query)
  Process.sleep(10000)
end

# Clean up
IO.puts("\nClosing session...")
Session.close(session)

# Detach telemetry handlers
:telemetry.detach("live-api-telemetry-demo")

IO.puts("\n=== Demo complete ===")

IO.puts("""

Telemetry Events Available:
- [:gemini, :live, :session, :init]      - Session initialization
- [:gemini, :live, :session, :ready]     - Session connected and ready
- [:gemini, :live, :session, :message, :sent]     - Message sent
- [:gemini, :live, :session, :message, :received] - Message received
- [:gemini, :live, :session, :tool_call] - Tool call requested
- [:gemini, :live, :session, :close]     - Session closed
- [:gemini, :live, :session, :error]     - Error occurred
- [:gemini, :live, :session, :go_away]   - GoAway notice received

WebSocket Events:
- [:gemini, :client, :websocket, :connect, :start] - Connection starting
- [:gemini, :client, :websocket, :connect, :stop]  - Connection completed
- [:gemini, :client, :websocket, :send]            - Message sent
""")
