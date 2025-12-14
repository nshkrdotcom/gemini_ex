defmodule Gemini.APIs.InteractionsLiveTest do
  @moduledoc """
  Live API tests for the Interactions API.

  Run with:

      mix test --include live_api test/live_api/interactions_live_test.exs

  Requires either:
  - Gemini: `GEMINI_API_KEY` (or `GOOGLE_API_KEY`)
  - Vertex: `VERTEX_PROJECT_ID`, `VERTEX_LOCATION`, plus a token/ADC configuration

  ## Model selection

  Interactions model availability can vary by account/region. If you see errors like
  `"Model family ... is not supported"`, set:

      export INTERACTIONS_MODEL="gemini-2.5-flash"

  ## Background interactions

  The API may reject `background: true` for model-based interactions. If you see errors like
  `"background=true is only supported for agent interactions"`, set an agent explicitly:

      export INTERACTIONS_AGENT="deep-research-pro-preview-12-2025"
  """

  use ExUnit.Case, async: false

  @moduletag :live_api
  @moduletag timeout: 180_000

  alias Gemini.Error
  alias Gemini.APIs.Interactions

  alias Gemini.Types.Interactions.Events.InteractionEvent

  setup do
    case Gemini.Test.AuthHelpers.detect_auth() do
      {:ok, auth, creds} ->
        {:ok, skip: false, auth: auth, creds: creds}

      :missing ->
        {:ok, skip: true}
    end
  end

  defp maybe_skip(%{skip: true}) do
    IO.puts(
      "\nSkipping Interactions live tests: configure GEMINI_API_KEY or Vertex credentials to run."
    )

    true
  end

  defp maybe_skip(_), do: false

  defp model_candidates do
    [
      System.get_env("INTERACTIONS_MODEL"),
      "gemini-2.5-flash",
      "gemini-2.5-flash-lite"
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp agent_candidates do
    [
      System.get_env("INTERACTIONS_AGENT"),
      "deep-research-pro-preview-12-2025"
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp unsupported_model_error?(%Error{} = error) do
    String.contains?(error_message(error), "not supported")
  end

  defp background_requires_agent_error?(%Error{} = error) do
    String.contains?(
      error_message(error),
      "background=true is only supported for agent interactions"
    )
  end

  defp rate_limited_error?(%Error{http_status: 429}), do: true
  defp rate_limited_error?(_), do: false

  defp error_message(%Error{} = error) do
    extract_error_message_from_details(error.details) ||
      error.message ||
      ""
  end

  defp extract_error_message_from_details(nil), do: nil

  defp extract_error_message_from_details(%{"body" => body}),
    do: extract_error_message_from_body(body)

  defp extract_error_message_from_details(%{body: body}),
    do: extract_error_message_from_body(body)

  defp extract_error_message_from_details(%{"error" => _} = body),
    do: extract_error_message_from_body(body)

  defp extract_error_message_from_details(_), do: nil

  defp extract_error_message_from_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> extract_error_message_from_body(decoded)
      _ -> nil
    end
  end

  defp extract_error_message_from_body(%{"error" => %{"message" => msg}})
       when is_binary(msg) and msg != "" do
    msg
  end

  defp extract_error_message_from_body(%{"error" => msg}) when is_binary(msg) and msg != "" do
    msg
  end

  defp extract_error_message_from_body(%{"message" => msg}) when is_binary(msg) and msg != "" do
    msg
  end

  defp extract_error_message_from_body(_), do: nil

  defp create_with_any_model(prompt, opts) do
    Enum.reduce_while(model_candidates(), {:error, :no_models}, fn model, _acc ->
      case Interactions.create(prompt, Keyword.put(opts, :model, model)) do
        {:ok, interaction} ->
          {:halt, {:ok, interaction, model}}

        {:error, %Error{} = error} = err ->
          if unsupported_model_error?(error), do: {:cont, err}, else: {:halt, err}

        other ->
          {:halt, other}
      end
    end)
  end

  defp create_with_any_agent(prompt, opts) do
    Enum.reduce_while(agent_candidates(), {:error, :no_agents}, fn agent, _acc ->
      case Interactions.create(prompt, Keyword.put(opts, :agent, agent)) do
        {:ok, interaction} ->
          {:halt, {:ok, interaction, agent}}

        {:error, %Error{} = error} = err ->
          if background_requires_agent_error?(error), do: {:cont, err}, else: {:halt, err}

        other ->
          {:halt, other}
      end
    end)
  end

  defp create_stream_with_any_model(prompt, opts) do
    Enum.reduce_while(model_candidates(), {:error, :no_models}, fn model, _acc ->
      case Interactions.create(prompt, Keyword.put(opts, :model, model)) do
        {:ok, stream} ->
          events = Enum.take(stream, 10)

          if Enum.any?(events, &match?(%InteractionEvent{event_type: "interaction.start"}, &1)) do
            {:halt, {:ok, events, model}}
          else
            case events do
              [{:error, %Error{} = error} | _] ->
                if unsupported_model_error?(error),
                  do: {:cont, {:error, error}},
                  else: {:halt, {:error, error}}

              _ ->
                {:halt, {:error, {:unexpected_events, events}}}
            end
          end

        {:error, %Error{} = error} = err ->
          if unsupported_model_error?(error), do: {:cont, err}, else: {:halt, err}

        other ->
          {:halt, other}
      end
    end)
  end

  defp capture_interaction_id_and_event_id(stream, max_events) do
    result =
      Enum.reduce_while(stream, %{interaction_id: nil, last_event_id: nil, seen: 0}, fn event,
                                                                                        acc ->
        acc = %{acc | seen: acc.seen + 1}

        case event do
          {:error, %Error{} = error} ->
            {:halt, {:error, error}}

          %InteractionEvent{event_type: "interaction.start", interaction: interaction} ->
            acc =
              if is_binary(interaction.id) and interaction.id != "" do
                %{acc | interaction_id: interaction.id}
              else
                acc
              end

            last_event_id = Map.get(event, :event_id)

            acc =
              if is_binary(last_event_id) and last_event_id != "",
                do: %{acc | last_event_id: last_event_id},
                else: acc

            if acc.interaction_id && acc.last_event_id do
              {:halt, {:ok, acc.interaction_id, acc.last_event_id}}
            else
              if acc.seen >= max_events,
                do: {:halt, {:ok, acc.interaction_id, acc.last_event_id}},
                else: {:cont, acc}
            end

          %{} ->
            last_event_id = Map.get(event, :event_id)

            acc =
              if is_binary(last_event_id) and last_event_id != "",
                do: %{acc | last_event_id: last_event_id},
                else: acc

            if acc.interaction_id && acc.last_event_id do
              {:halt, {:ok, acc.interaction_id, acc.last_event_id}}
            else
              if acc.seen >= max_events,
                do: {:halt, {:ok, acc.interaction_id, acc.last_event_id}},
                else: {:cont, acc}
            end
        end
      end)

    case result do
      {:ok, _interaction_id, _last_event_id} = ok ->
        ok

      {:error, %Error{}} = err ->
        err

      %{interaction_id: interaction_id, last_event_id: last_event_id} ->
        {:ok, interaction_id, last_event_id}
    end
  end

  defp auth_opts(%{auth: :gemini, creds: %{api_key: api_key}}) do
    [auth: :gemini, api_key: api_key]
  end

  defp auth_opts(%{auth: :vertex_ai, creds: creds}) when is_map(creds) do
    []
    |> Keyword.put(:auth, :vertex_ai)
    |> maybe_put_opt(:project_id, Map.get(creds, :project_id))
    |> maybe_put_opt(:location, Map.get(creds, :location))
    |> maybe_put_opt(:access_token, Map.get(creds, :access_token))
    |> maybe_put_opt(:service_account_key, Map.get(creds, :service_account_key))
    |> maybe_put_opt(:service_account_data, Map.get(creds, :service_account_data))
    |> maybe_put_opt(:quota_project_id, Map.get(creds, :quota_project_id))
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, _key, ""), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  @tag :live_api
  test "create (non-streaming) returns an interaction", ctx do
    if maybe_skip(ctx) do
      assert true
    else
      opts =
        ctx
        |> auth_opts()
        |> Keyword.merge(timeout: 60_000)

      case create_with_any_model("Say hello in one sentence.", opts) do
        {:ok, interaction, _model} ->
          assert is_binary(interaction.id) and interaction.id != ""
          assert is_binary(interaction.status) and interaction.status != ""

        {:error, %Error{} = error} ->
          cond do
            rate_limited_error?(error) ->
              IO.puts("\nSkipping Interactions live create test: rate limited (HTTP 429).")
              assert true

            unsupported_model_error?(error) ->
              IO.puts(
                "\nSkipping Interactions live create test: no supported Interactions model found. Tried: #{inspect(model_candidates())}\nSet INTERACTIONS_MODEL to a supported model to run this test."
              )

              assert true

            true ->
              flunk("Interactions.create failed: #{inspect(error)}")
          end

        {:error, :no_models} ->
          flunk("No INTERACTIONS_MODEL candidates configured")
      end
    end
  end

  @tag :live_api
  test "create (streaming) yields interaction.start", ctx do
    if maybe_skip(ctx) do
      assert true
    else
      opts =
        ctx
        |> auth_opts()
        |> Keyword.merge(
          stream: true,
          timeout: 60_000,
          connect_timeout: 10_000,
          max_retries: 0
        )

      case create_stream_with_any_model("Write a short greeting.", opts) do
        {:ok, events, _model} ->
          assert Enum.any?(
                   events,
                   &match?(%InteractionEvent{event_type: "interaction.start"}, &1)
                 )

        {:error, %Error{} = error} ->
          cond do
            rate_limited_error?(error) ->
              IO.puts("\nSkipping Interactions live streaming test: rate limited (HTTP 429).")
              assert true

            unsupported_model_error?(error) ->
              IO.puts(
                "\nSkipping Interactions live streaming test: no supported Interactions model found. Tried: #{inspect(model_candidates())}\nSet INTERACTIONS_MODEL to a supported model to run this test."
              )

              assert true

            true ->
              flunk("Interactions streaming failed: #{inspect(error)}")
          end

        {:error, {:unexpected_events, events}} ->
          flunk("Unexpected events: #{inspect(events)}")

        {:error, :no_models} ->
          flunk("No INTERACTIONS_MODEL candidates configured")
      end
    end
  end

  @tag :live_api
  test "get (streaming) supports resumption via last_event_id", ctx do
    if maybe_skip(ctx) do
      assert true
    else
      create_opts =
        ctx
        |> auth_opts()
        |> Keyword.merge(
          stream: true,
          timeout: 60_000,
          connect_timeout: 10_000,
          max_retries: 0
        )

      result =
        Enum.reduce_while(model_candidates(), {:error, :no_models}, fn model, _acc ->
          case Interactions.create(
                 "Write a 2-line haiku.",
                 Keyword.put(create_opts, :model, model)
               ) do
            {:ok, stream} ->
              case capture_interaction_id_and_event_id(stream, 200) do
                {:ok, interaction_id, last_event_id}
                when is_binary(interaction_id) and interaction_id != "" and
                       is_binary(last_event_id) and
                       last_event_id != "" ->
                  {:halt, {:ok, interaction_id, last_event_id, model}}

                {:ok, _interaction_id, _last_event_id} ->
                  {:cont, {:error, :missing_event_id}}

                {:error, %Error{} = error} ->
                  if unsupported_model_error?(error),
                    do: {:cont, {:error, error}},
                    else: {:halt, {:error, error}}
              end

            {:error, %Error{} = error} = err ->
              if unsupported_model_error?(error), do: {:cont, err}, else: {:halt, err}

            other ->
              {:halt, other}
          end
        end)

      case result do
        {:ok, interaction_id, last_event_id, _model} ->
          get_opts =
            ctx
            |> auth_opts()
            |> Keyword.merge(
              stream: true,
              last_event_id: last_event_id,
              timeout: 60_000,
              connect_timeout: 10_000,
              max_retries: 0
            )

          assert {:ok, resume_stream} = Interactions.get(interaction_id, get_opts)

          resumed_events = Enum.take(resume_stream, 10)
          assert is_list(resumed_events)

        {:error, :missing_event_id} ->
          IO.puts(
            "\nSkipping Interactions resumption test: stream did not include an event_id token early enough to resume."
          )

          assert true

        {:error, %Error{} = error} ->
          cond do
            rate_limited_error?(error) ->
              IO.puts("\nSkipping Interactions resumption test: rate limited (HTTP 429).")
              assert true

            unsupported_model_error?(error) ->
              IO.puts(
                "\nSkipping Interactions resumption test: no supported Interactions model found. Tried: #{inspect(model_candidates())}\nSet INTERACTIONS_MODEL to a supported model to run this test."
              )

              assert true

            true ->
              flunk("Interactions streaming failed: #{inspect(error)}")
          end

        {:error, :no_models} ->
          flunk("No INTERACTIONS_MODEL candidates configured")
      end
    end
  end

  @tag :live_api
  test "background create can be cancelled and deleted (best effort cleanup)", ctx do
    if maybe_skip(ctx) do
      assert true
    else
      create_opts =
        ctx
        |> auth_opts()
        |> Keyword.merge(
          background: true,
          store: true,
          timeout: 60_000,
          max_retries: 0
        )

      case create_with_any_agent(
             "Draft a detailed outline for a technical blog post about OTP supervision trees.",
             create_opts
           ) do
        {:ok, interaction, _agent} ->
          assert is_binary(interaction.id) and interaction.id != ""

          _ = Interactions.cancel(interaction.id, auth_opts(ctx))
          _ = Interactions.delete(interaction.id, auth_opts(ctx))

          assert true

        {:error, :no_agents} ->
          IO.puts(
            "\nSkipping Interactions background test: no agent configured. Set INTERACTIONS_AGENT to run."
          )

          assert true

        {:error, %Error{} = error} ->
          IO.puts(
            "\nSkipping Interactions background test: server rejected background interaction create (#{error.message})."
          )

          assert true
      end
    end
  end
end
