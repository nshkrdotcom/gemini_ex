defmodule Gemini.Types.Response.BatchStateTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.BatchState

  describe "from_string/1" do
    test "converts STATE_UNSPECIFIED to :unspecified" do
      assert BatchState.from_string("STATE_UNSPECIFIED") == :unspecified
    end

    test "converts PENDING to :pending" do
      assert BatchState.from_string("PENDING") == :pending
    end

    test "converts PROCESSING to :processing" do
      assert BatchState.from_string("PROCESSING") == :processing
    end

    test "converts COMPLETED to :completed" do
      assert BatchState.from_string("COMPLETED") == :completed
    end

    test "converts FAILED to :failed" do
      assert BatchState.from_string("FAILED") == :failed
    end

    test "converts CANCELLED to :cancelled" do
      assert BatchState.from_string("CANCELLED") == :cancelled
    end

    test "handles lowercase strings" do
      assert BatchState.from_string("pending") == :pending
      assert BatchState.from_string("processing") == :processing
      assert BatchState.from_string("completed") == :completed
    end

    test "defaults unknown states to :unspecified" do
      assert BatchState.from_string("UNKNOWN") == :unspecified
      assert BatchState.from_string("invalid") == :unspecified
      assert BatchState.from_string("") == :unspecified
    end
  end

  describe "to_string/1" do
    test "converts :unspecified to STATE_UNSPECIFIED" do
      assert BatchState.to_string(:unspecified) == "STATE_UNSPECIFIED"
    end

    test "converts :pending to PENDING" do
      assert BatchState.to_string(:pending) == "PENDING"
    end

    test "converts :processing to PROCESSING" do
      assert BatchState.to_string(:processing) == "PROCESSING"
    end

    test "converts :completed to COMPLETED" do
      assert BatchState.to_string(:completed) == "COMPLETED"
    end

    test "converts :failed to FAILED" do
      assert BatchState.to_string(:failed) == "FAILED"
    end

    test "converts :cancelled to CANCELLED" do
      assert BatchState.to_string(:cancelled) == "CANCELLED"
    end
  end

  describe "roundtrip conversion" do
    test "string -> atom -> string preserves value" do
      states = ["PENDING", "PROCESSING", "COMPLETED", "FAILED", "CANCELLED"]

      for state <- states do
        atom_state = BatchState.from_string(state)
        string_state = BatchState.to_string(atom_state)
        assert string_state == state
      end
    end
  end

  describe "type validation" do
    test "all valid states are atoms" do
      valid_states = [:unspecified, :pending, :processing, :completed, :failed, :cancelled]

      for state <- valid_states do
        assert is_atom(state)
      end
    end
  end
end
