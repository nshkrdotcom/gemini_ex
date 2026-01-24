# OTP Remediation Design (Pre-Implementation)

## Goals

- Eliminate unsupervised process creation in production code.
- Preserve existing public APIs where possible.
- Resolve Live Session callback deadlock without spawning ad-hoc processes.

## Supervision Strategy

- Introduce a named task supervisor (`Gemini.TaskSupervisor`) in the top-level
  supervision tree.
- Use `Gemini.TaskSupervisor.start_child/1` for short-lived background work that
  was previously spawned or spawn-linked.
- `Gemini.TaskSupervisor.start_child/1` will ensure the supervisor exists,
  allowing direct library usage outside of the application tree without
  reverting to bare `spawn`.

## ConcurrencyGate Holder Watchers

- Replace bare `spawn` with supervised tasks.
- Each holder watcher runs under `Gemini.TaskSupervisor` and continues to
  monitor the holder PID, releasing permits on DOWN.
- Failure to start a watcher will be surfaced (logged and returned) to avoid
  silent permit leaks.

## HTTPStreaming.stream_to_process

- Replace bare `spawn` with `Gemini.TaskSupervisor.start_child/1`.
- Wrap stream execution in `try/rescue/catch` to ensure target receives
  `{:stream_error, stream_id, reason}` on failures.
- Maintain existing `{:ok, pid}` return contract.

## ToolOrchestrator Tool Execution

- Replace `spawn_link` with `Gemini.TaskSupervisor.start_child/1`.
- Task wraps `Tools.execute_calls/1` in `try/rescue/catch` and sends
  `{:tool_execution_complete, result}` to the orchestrator.
- If the task fails to start, the orchestrator will send `{:stream_error, ...}`
  to the subscriber and stop cleanly.

## Interactions Streaming

- Replace `spawn_link` with `Gemini.TaskSupervisor.start_child/1`.
- The stream worker is no longer linked to the caller process, preventing
  unintended caller exits.
- Maintain existing `Stream.resource/3` behavior and messaging protocol.

## Live.Session Callback Deadlock

- Add a supported callback return path for tool calls:
  - `on_tool_call` may return `{:tool_response, responses}` or a list of tool
    responses, and the session will send these over the WebSocket directly.
- Update `send_tool_response/2` to avoid self-deadlock by using an async path
  when called from within the session process.
- Factor tool-response sending into a private helper to share logic between
  `handle_call`, `handle_cast`, and tool-call callback handling.
