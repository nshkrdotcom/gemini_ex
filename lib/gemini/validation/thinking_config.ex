defmodule Gemini.Validation.ThinkingConfig do
  @moduledoc """
  Validation for thinking configuration parameters based on model capabilities.

  Gemini 2.5 series models support thinking budgets with model-specific ranges:
  - **2.5 Pro**: 128-32,768 tokens (cannot disable with 0)
  - **2.5 Flash**: 0-24,576 tokens (can disable)
  - **2.5 Flash Lite**: 0 or 512-24,576 tokens

  Special value `-1` enables dynamic thinking (model decides budget) for all models.

  See: https://ai.google.dev/gemini-api/docs/thinking
  """

  @type validation_result :: :ok | {:error, String.t()}

  @doc """
  Validate thinking budget for a specific model.

  ## Parameters
  - `budget`: Integer budget value
  - `model`: Model name string

  ## Returns
  - `:ok` if valid
  - `{:error, message}` with helpful error message

  ## Examples

      iex> Gemini.Validation.ThinkingConfig.validate_budget(1024, "gemini-2.5-flash")
      :ok

      iex> Gemini.Validation.ThinkingConfig.validate_budget(0, "gemini-2.5-pro")
      {:error, "Gemini 2.5 Pro cannot disable thinking (minimum budget: 128)"}
  """
  @spec validate_budget(integer(), String.t()) :: validation_result()
  def validate_budget(budget, model) when is_integer(budget) and is_binary(model) do
    cond do
      budget == -1 ->
        # Dynamic thinking allowed for all models
        :ok

      String.contains?(model, "gemini-2.5-pro") or String.contains?(model, "gemini-pro-2.5") ->
        validate_pro_budget(budget)

      String.contains?(model, "gemini-2.5-flash-lite") ->
        validate_flash_lite_budget(budget)

      String.contains?(model, "gemini-2.5-flash") or String.contains?(model, "gemini-flash-2.5") ->
        validate_flash_budget(budget)

      true ->
        # Unknown model, allow any value (let API validate)
        :ok
    end
  end

  @doc """
  Validate complete thinking config including budget and include_thoughts.

  ## Parameters
  - `config`: Map or ThinkingConfig struct
  - `model`: Model name string

  ## Returns
  - `:ok` if valid
  - `{:error, message}` if invalid
  """
  @spec validate(map() | struct(), String.t()) :: validation_result()
  def validate(%{thinking_budget: budget}, model) when is_integer(budget) do
    validate_budget(budget, model)
  end

  def validate(_config, _model), do: :ok

  # Private validation functions for each model type

  defp validate_pro_budget(0) do
    {:error, "Gemini 2.5 Pro cannot disable thinking (minimum budget: 128)"}
  end

  defp validate_pro_budget(budget) when budget >= 128 and budget <= 32_768 do
    :ok
  end

  defp validate_pro_budget(budget) do
    {:error, "Gemini 2.5 Pro thinking budget must be between 128 and 32,768, got: #{budget}"}
  end

  defp validate_flash_budget(budget) when budget >= 0 and budget <= 24_576 do
    :ok
  end

  defp validate_flash_budget(budget) do
    {:error, "Gemini 2.5 Flash thinking budget must be between 0 and 24,576, got: #{budget}"}
  end

  defp validate_flash_lite_budget(0), do: :ok

  defp validate_flash_lite_budget(budget)
       when budget >= 512 and budget <= 24_576 do
    :ok
  end

  defp validate_flash_lite_budget(budget) do
    {:error,
     "Gemini 2.5 Flash Lite thinking budget must be 0 or between 512 and 24,576, got: #{budget}"}
  end
end
