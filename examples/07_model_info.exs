# Model Information Example
# Run with: mix run examples/07_model_info.exs
#
# Demonstrates:
# - Listing available models
# - Getting model details
# - Understanding model capabilities

defmodule ModelInfoExample do
  def run do
    print_header("MODEL INFORMATION")

    check_auth!()

    demo_list_models()
    demo_model_details()
    demo_model_comparison()

    print_footer()
  end

  # ============================================================
  # Demo 1: List Available Models
  # ============================================================
  defp demo_list_models do
    print_section("1. List Available Models")

    case Gemini.list_models() do
      {:ok, response} ->
        models = Map.get(response, "models", [])
        IO.puts("Found #{length(models)} models:")
        IO.puts("")

        # Group by model family
        grouped =
          models
          |> Enum.group_by(fn model ->
            name = Map.get(model, "name", "")

            cond do
              String.contains?(name, "gemini-2") -> "Gemini 2.x"
              String.contains?(name, "gemini-1.5") -> "Gemini 1.5"
              String.contains?(name, "gemini-1.0") -> "Gemini 1.0"
              String.contains?(name, "embedding") -> "Embedding Models"
              String.contains?(name, "aqa") -> "AQA Models"
              true -> "Other"
            end
          end)

        Enum.each(grouped, fn {family, family_models} ->
          IO.puts("#{family}:")

          Enum.take(family_models, 5)
          |> Enum.each(fn model ->
            name = Map.get(model, "name", "unknown")
            display = Map.get(model, "displayName", "")
            IO.puts("  - #{name}")
            if display != "", do: IO.puts("    Display: #{display}")
          end)

          if length(family_models) > 5 do
            IO.puts("  ... and #{length(family_models) - 5} more")
          end

          IO.puts("")
        end)

        IO.puts("[OK] Listed #{length(models)} models")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Get Specific Model Details
  # ============================================================
  defp demo_model_details do
    print_section("2. Model Details")

    # Try a few common models
    models_to_check = [
      Gemini.Config.get_model(:flash_lite_latest),
      "models/gemini-1.5-flash",
      "models/gemini-1.5-pro"
    ]

    Enum.each(models_to_check, fn model_name ->
      IO.puts("MODEL: #{model_name}")

      case Gemini.get_model(model_name) do
        {:ok, model} ->
          IO.puts("  Display Name: #{Map.get(model, "displayName", "N/A")}")

          IO.puts(
            "  Description: #{String.slice(Map.get(model, "description", "N/A"), 0, 80)}..."
          )

          IO.puts("  Version: #{Map.get(model, "version", "N/A")}")
          IO.puts("")

          # Token limits
          input_limit = Map.get(model, "inputTokenLimit", 0)
          output_limit = Map.get(model, "outputTokenLimit", 0)
          IO.puts("  TOKEN LIMITS:")
          IO.puts("    Input:  #{format_number(input_limit)} tokens")
          IO.puts("    Output: #{format_number(output_limit)} tokens")
          IO.puts("")

          # Supported methods
          methods = Map.get(model, "supportedGenerationMethods", [])
          IO.puts("  SUPPORTED METHODS:")
          Enum.each(methods, &IO.puts("    - #{&1}"))
          IO.puts("")

        {:error, _} ->
          IO.puts("  [NOT FOUND or ERROR]")
          IO.puts("")
      end
    end)

    IO.puts("[OK] Model details retrieved")
    IO.puts("")
  end

  # ============================================================
  # Demo 3: Model Comparison Table
  # ============================================================
  defp demo_model_comparison do
    print_section("3. Model Comparison")

    models = [
      "models/gemini-2.5-flash",
      "models/gemini-2.5-pro",
      "models/gemini-3-pro-preview",
      "models/gemini-embedding-001"
    ]

    IO.puts("COMPARISON TABLE:")
    IO.puts("")

    IO.puts(
      String.pad_trailing("Model", 35) <>
        String.pad_trailing("Input", 12) <>
        String.pad_trailing("Output", 12) <>
        "Methods"
    )

    IO.puts(String.duplicate("-", 80))

    Enum.each(models, fn model_name ->
      case Gemini.get_model(model_name) do
        {:ok, model} ->
          short_name =
            model_name
            |> String.replace("models/", "")
            |> String.slice(0, 33)

          input = format_number(Map.get(model, "inputTokenLimit", 0))
          output = format_number(Map.get(model, "outputTokenLimit", 0))
          methods = Map.get(model, "supportedGenerationMethods", []) |> Enum.join(", ")

          IO.puts(
            String.pad_trailing(short_name, 35) <>
              String.pad_trailing(input, 12) <>
              String.pad_trailing(output, 12) <>
              String.slice(methods, 0, 30)
          )

        {:error, _} ->
          short_name = String.replace(model_name, "models/", "")
          IO.puts(String.pad_trailing(short_name, 35) <> "[not available]")
      end
    end)

    IO.puts("")
    IO.puts("[OK] Comparison complete")
    IO.puts("")
  end

  # ============================================================
  # Helper Functions
  # ============================================================
  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(_), do: "N/A"

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

ModelInfoExample.run()
