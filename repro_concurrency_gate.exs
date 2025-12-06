alias Gemini.RateLimiter.{Manager, ConcurrencyGate}

defmodule ConcurrencyGateRepro do
  def run(iterations \\ 500, tasks_per_round \\ 8, sleep_ms \\ 10) do
    ConcurrencyGate.init()
    Manager.reset_all()

    for i <- 1..iterations do
      counter = :atomics.new(1, [])
      max_seen = :atomics.new(1, [])
      model = "repro-gate-#{i}-#{System.unique_integer([:positive])}"

      request_fn = fn ->
        current = :atomics.add_get(counter, 1, 1)
        bump_max(max_seen, current)
        Process.sleep(sleep_ms)
        :atomics.add(counter, 1, -1)
        {:ok, :done}
      end

      tasks =
        for _ <- 1..tasks_per_round do
          Task.async(fn ->
            Manager.execute(request_fn, model, max_concurrency_per_model: 1)
          end)
        end

      results = Task.await_many(tasks, 5_000)

      unless Enum.all?(results, &match?({:ok, _}, &1)),
        do: raise("unexpected result: #{inspect(results)}")

      peak = :atomics.get(max_seen, 1)

      if peak > 1 do
        IO.puts("FAIL iteration=#{i} peak=#{peak} tasks=#{tasks_per_round} sleep_ms=#{sleep_ms}")
        System.halt(1)
      end
    end

    IO.puts(
      "PASS no overlaps after #{iterations} iterations (tasks=#{tasks_per_round}, sleep_ms=#{sleep_ms})"
    )
  end

  defp bump_max(ref, value) do
    current = :atomics.get(ref, 1)

    if value > current do
      :atomics.compare_exchange(ref, 1, current, value)
    end

    :ok
  end
end

ConcurrencyGateRepro.run()
