defmodule Gemini.Types.Interactions.Events.Error do
  @moduledoc """
  Error payload inside an Interactions SSE `error` event.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:code, String.t())
    field(:message, String.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = err), do: err

  def from_api(%{} = data) do
    %__MODULE__{
      code: Map.get(data, "code"),
      message: Map.get(data, "message")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = err) do
    %{}
    |> maybe_put("code", err.code)
    |> maybe_put("message", err.message)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Events.ErrorEvent do
  @moduledoc """
  Interactions SSE event: `event_type: "error"`.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Events.Error

  @derive Jason.Encoder
  typedstruct do
    field(:event_id, String.t())
    field(:event_type, String.t())
    field(:error, Error.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = event), do: event

  def from_api(%{} = data) do
    %__MODULE__{
      event_id: Map.get(data, "event_id"),
      event_type: Map.get(data, "event_type"),
      error: Error.from_api(Map.get(data, "error"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = event) do
    %{"event_type" => "error"}
    |> maybe_put("event_id", event.event_id)
    |> maybe_put("error", Error.to_api(event.error))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Events.InteractionEvent do
  @moduledoc """
  Interactions SSE event: `interaction.start` or `interaction.complete`.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Interaction

  @type event_type :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:event_id, String.t())
    field(:event_type, event_type())
    field(:interaction, Interaction.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = event), do: event

  def from_api(%{} = data) do
    %__MODULE__{
      event_id: Map.get(data, "event_id"),
      event_type: Map.get(data, "event_type"),
      interaction: Interaction.from_api(Map.get(data, "interaction"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = event) do
    %{}
    |> maybe_put("event_id", event.event_id)
    |> maybe_put("event_type", event.event_type)
    |> maybe_put("interaction", Interaction.to_api(event.interaction))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Events.InteractionStatusUpdate do
  @moduledoc """
  Interactions SSE event: `interaction.status_update`.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Interaction

  @derive Jason.Encoder
  typedstruct do
    field(:event_id, String.t())
    field(:event_type, String.t())
    field(:interaction_id, String.t())
    field(:status, Interaction.status())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = event), do: event

  def from_api(%{} = data) do
    %__MODULE__{
      event_id: Map.get(data, "event_id"),
      event_type: Map.get(data, "event_type"),
      interaction_id: Map.get(data, "interaction_id"),
      status: Map.get(data, "status")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = event) do
    %{"event_type" => "interaction.status_update"}
    |> maybe_put("event_id", event.event_id)
    |> maybe_put("interaction_id", event.interaction_id)
    |> maybe_put("status", event.status)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Events.ContentStart do
  @moduledoc """
  Interactions SSE event: `content.start`.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Content

  @derive Jason.Encoder
  typedstruct do
    field(:event_id, String.t())
    field(:event_type, String.t())
    field(:index, non_neg_integer())
    field(:content, Content.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = event), do: event

  def from_api(%{} = data) do
    %__MODULE__{
      event_id: Map.get(data, "event_id"),
      event_type: Map.get(data, "event_type"),
      index: Map.get(data, "index"),
      content: Content.from_api(Map.get(data, "content"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = event) do
    %{"event_type" => "content.start"}
    |> maybe_put("event_id", event.event_id)
    |> maybe_put("index", event.index)
    |> maybe_put("content", Content.to_api(event.content))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Events.ContentDelta do
  @moduledoc """
  Interactions SSE event: `content.delta`.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Delta

  @derive Jason.Encoder
  typedstruct do
    field(:event_id, String.t())
    field(:event_type, String.t())
    field(:index, non_neg_integer())
    field(:delta, Delta.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = event), do: event

  def from_api(%{} = data) do
    %__MODULE__{
      event_id: Map.get(data, "event_id"),
      event_type: Map.get(data, "event_type"),
      index: Map.get(data, "index"),
      delta: Delta.from_api(Map.get(data, "delta"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = event) do
    %{"event_type" => "content.delta"}
    |> maybe_put("event_id", event.event_id)
    |> maybe_put("index", event.index)
    |> maybe_put("delta", Delta.to_api(event.delta))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Events.ContentStop do
  @moduledoc """
  Interactions SSE event: `content.stop`.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:event_id, String.t())
    field(:event_type, String.t())
    field(:index, non_neg_integer())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = event), do: event

  def from_api(%{} = data) do
    %__MODULE__{
      event_id: Map.get(data, "event_id"),
      event_type: Map.get(data, "event_type"),
      index: Map.get(data, "index")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = event) do
    %{"event_type" => "content.stop"}
    |> maybe_put("event_id", event.event_id)
    |> maybe_put("index", event.index)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Events.InteractionSSEEvent do
  @moduledoc """
  Union type for Interactions SSE events (6 variants).
  """

  alias Gemini.Types.Interactions.Events.{
    ContentDelta,
    ContentStart,
    ContentStop,
    ErrorEvent,
    InteractionEvent,
    InteractionStatusUpdate
  }

  @type t ::
          InteractionEvent.t()
          | InteractionStatusUpdate.t()
          | ContentStart.t()
          | ContentDelta.t()
          | ContentStop.t()
          | ErrorEvent.t()
end

defmodule Gemini.Types.Interactions.Events do
  @moduledoc """
  Helpers for decoding Interactions SSE events.
  """

  alias Gemini.Types.Interactions.Events.{
    ContentDelta,
    ContentStart,
    ContentStop,
    ErrorEvent,
    InteractionEvent,
    InteractionStatusUpdate,
    InteractionSSEEvent
  }

  @spec from_api(map() | InteractionSSEEvent.t() | nil) :: InteractionSSEEvent.t() | nil
  def from_api(nil), do: nil
  def from_api(%_{} = event), do: event

  def from_api(%{} = data) do
    case Map.get(data, "event_type") do
      "interaction.start" -> InteractionEvent.from_api(data)
      "interaction.complete" -> InteractionEvent.from_api(data)
      "interaction.status_update" -> InteractionStatusUpdate.from_api(data)
      "content.start" -> ContentStart.from_api(data)
      "content.delta" -> ContentDelta.from_api(data)
      "content.stop" -> ContentStop.from_api(data)
      "error" -> ErrorEvent.from_api(data)
      _ -> nil
    end
  end
end
