# Utility Functions and Helpers Gap Analysis

## Executive Summary

The Elixir port has basic utility support with excellent resource name normalization, but is missing several convenience functions present in the Python genai library. Most gaps are **quick wins** (< 30 lines) that can significantly improve developer experience.

### Python Utilities Overview
- **_common.py** (25 functions) - Text transformation, path navigation, merging
- **_extra_utils.py** (20+ functions) - Function calling, AFC, config helpers
- **_transformers.py** (45 functions) - Content transformation
- **_mcp_utils.py** (5 functions) - MCP tool handling
- **_base_url.py** (2 functions) - URL management
- **local_tokenizer.py** - Token counting (advanced)
- **pagers.py** - Pagination helpers

### Elixir Implementation Status
- `Gemini.Utils.ResourceNames` - Excellent (Google Cloud resource name normalization)
- Basic text helpers in `Content` and `Part` modules
- `extract_text` implementations (3 different versions)
- Model/text normalization in request types

---

## High Priority Quick Wins (< 30 lines each)

### 1. Dict Path Navigation Utilities

**Python equivalent:** `set_value_by_path/get_value_by_path`

**Use case:** Deep dictionary manipulation for API request building

```elixir
defmodule Gemini.Utils.DictPath do
  @moduledoc """
  Utilities for getting/setting/moving values in nested maps using path notation.
  Supports array notation: "a.b[].c" for array iteration.
  """

  @spec get_value(map(), [String.t() | atom()], any()) :: any()
  def get_value(data, [], default), do: data || default
  def get_value(data, [key | rest], default) when is_map(data) do
    case Map.get(data, key) || Map.get(data, to_string(key)) do
      nil -> default
      value -> get_value(value, rest, default)
    end
  end
  def get_value(_, _, default), do: default

  @spec set_value(map(), [String.t() | atom()], any()) :: map()
  def set_value(data, [key], value), do: Map.put(data, key, value)
  def set_value(data, [key | rest], value) do
    nested = Map.get(data, key, %{})
    Map.put(data, key, set_value(nested, rest, value))
  end
end
```

**Priority:** HIGH - Used internally for API request building
**Effort:** 20-25 lines

### 2. Snake Case to Camel Case Converter

**Python equivalent:** `snake_to_camel`

**Use case:** API compatibility between Elixir conventions and Google API

```elixir
defmodule Gemini.Utils.CaseConverter do
  @spec snake_to_camel(String.t()) :: String.t()
  def snake_to_camel(snake_str) do
    snake_str
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map(fn {word, 0} -> word; {word, _} -> String.capitalize(word) end)
    |> Enum.join()
  end

  @spec camel_to_snake(String.t()) :: String.t()
  def camel_to_snake(camel_str) do
    camel_str
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
  end
end
```

**Priority:** MEDIUM - Useful for API compatibility
**Effort:** 5-10 lines total

### 3. Timestamped Unique Name Generator

**Python equivalent:** `timestamped_unique_name`

**Use case:** Batch job names, cache names, operation IDs

```elixir
defmodule Gemini.Utils.NameGenerator do
  @spec timestamped_unique_name(String.t()) :: String.t()
  def timestamped_unique_name(prefix \\ "") do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d%H%M%S")
    unique = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "#{prefix}#{timestamp}_#{unique}"
  end
end
```

**Priority:** MEDIUM - Used for resource naming
**Effort:** 4-6 lines

### 4. Number Type Conversion for Function Calls

**Python equivalent:** `convert_number_values_for_function_call_args`

**Use case:** Fixes function argument type matching (5.0 -> 5)

```elixir
defmodule Gemini.Utils.FunctionCallHelper do
  @spec convert_numbers(any()) :: any()
  def convert_numbers(value) when is_float(value) do
    if trunc(value) == value, do: trunc(value), else: value
  end
  def convert_numbers(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, convert_numbers(v)} end)
  end
  def convert_numbers(value) when is_list(value) do
    Enum.map(value, &convert_numbers/1)
  end
  def convert_numbers(value), do: value
end
```

**Priority:** MEDIUM - Fixes function calling issues
**Effort:** 10-15 lines

---

## Medium Priority (20-50 lines each)

### 5. Recursive Dictionary Update

**Python equivalent:** `recursive_dict_update/align_key_case`

```elixir
defmodule Gemini.Utils.MapMerge do
  @spec recursive_merge(map(), map()) :: map()
  def recursive_merge(target, update) when is_map(target) and is_map(update) do
    Map.merge(target, update, fn
      _key, v1, v2 when is_map(v1) and is_map(v2) -> recursive_merge(v1, v2)
      _key, _v1, v2 -> v2
    end)
  end

  @spec align_keys(map(), atom()) :: map()
  def align_keys(map, :snake) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: Gemini.Utils.CaseConverter.camel_to_snake(k), else: k
      value = if is_map(v), do: align_keys(v, :snake), else: v
      {key, value}
    end)
  end
  def align_keys(map, :camel) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: Gemini.Utils.CaseConverter.snake_to_camel(k), else: k
      value = if is_map(v), do: align_keys(v, :camel), else: v
      {key, value}
    end)
  end
end
```

**Priority:** MEDIUM - Needed for request building
**Effort:** 45-55 lines total

### 6. File Upload Preparation Helper

**Python equivalent:** `prepare_resumable_upload`

```elixir
defmodule Gemini.Utils.FileUpload do
  @spec prepare_resumable_upload(Path.t() | File.io_device(), keyword()) ::
    {:ok, {map(), non_neg_integer(), String.t()}} | {:error, term()}
  def prepare_resumable_upload(file_path, opts \\ []) when is_binary(file_path) do
    with {:ok, stat} <- File.stat(file_path),
         mime_type <- opts[:mime_type] || guess_mime_type(file_path) do
      headers = %{
        "X-Goog-Upload-Protocol" => "resumable",
        "X-Goog-Upload-Command" => "start",
        "X-Goog-Upload-Header-Content-Length" => to_string(stat.size),
        "X-Goog-Upload-Header-Content-Type" => mime_type
      }
      {:ok, {headers, stat.size, mime_type}}
    end
  end

  defp guess_mime_type(path) do
    case Path.extname(path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".mp4" -> "video/mp4"
      ".pdf" -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end
end
```

**Priority:** MEDIUM - For file upload features
**Effort:** 30-40 lines

### 7. Pagination Helper

**Python equivalent:** `Pager/AsyncPager`

```elixir
defmodule Gemini.Utils.Pagination do
  @moduledoc """
  Utilities for pagination with next_page_token.
  """

  defstruct [:items, :next_page_token, :request_fn, :config]

  @spec stream(t()) :: Enumerable.t()
  def stream(%__MODULE__{} = pager) do
    Stream.unfold(pager, fn
      nil -> nil
      %{items: [], next_page_token: nil} -> nil
      %{items: [], next_page_token: token} = p ->
        case fetch_next_page(p, token) do
          {:ok, new_pager} -> stream_next(new_pager)
          {:error, _} -> nil
        end
      %{items: [item | rest]} = p ->
        {item, %{p | items: rest}}
    end)
  end

  defp fetch_next_page(%{request_fn: request_fn, config: config}, token) do
    request_fn.(Map.put(config, :page_token, token))
  end
end
```

**Priority:** MEDIUM - For comprehensive list APIs
**Effort:** 30-40 lines

---

## Lower Priority / Advanced (50+ lines)

### 8. Enhanced Content Text Extractor

**Already partially implemented, needs enhancement**

```elixir
defmodule Gemini.Utils.ContentExtractor do
  @spec extract_all_text(GenerateContentResponse.t() | [any()]) :: [String.t()]
  def extract_all_text(%{candidates: candidates}) when is_list(candidates) do
    Enum.flat_map(candidates, fn candidate ->
      extract_text_from_content(candidate.content)
    end)
  end

  @spec extract_function_calls(GenerateContentResponse.t()) :: [FunctionCall.t()]
  def extract_function_calls(%{candidates: candidates}) when is_list(candidates) do
    candidates
    |> Enum.flat_map(fn c -> c.content.parts || [] end)
    |> Enum.filter(&match?(%{function_call: %{}}, &1))
    |> Enum.map(& &1.function_call)
  end

  defp extract_text_from_content(%{parts: parts}) when is_list(parts) do
    Enum.flat_map(parts, fn
      %{text: text} when is_binary(text) -> [text]
      _ -> []
    end)
  end
  defp extract_text_from_content(_), do: []
end
```

**Priority:** LOW - Partially implemented already
**Effort:** 35-50 lines

### 9. Local Tokenizer (Advanced)

**Python equivalent:** `LocalTokenizer`

**Note:** Would require external dependency (SentencePiece NIF or API)

```elixir
defmodule Gemini.LocalTokenizer do
  @moduledoc """
  [Experimental] Text-only local tokenizer for token counting.
  Requires downloading/caching tokenizer models.
  """

  @spec count_tokens(String.t(), String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def count_tokens(text, model_name) do
    # Would need SentencePiece library or similar
    # This is a placeholder for the interface
    {:error, :not_implemented}
  end
end
```

**Priority:** VERY LOW - Requires external dependency
**Effort:** 50+ lines plus dependency management

---

## Implementation Priority Matrix

| Utility | Priority | Effort | Value | Status |
|---------|----------|--------|-------|--------|
| Dict Path Navigation | HIGH | 25 lines | HIGH | NOT IMPLEMENTED |
| Snake/Camel Conversion | MEDIUM | 10 lines | MEDIUM | NOT IMPLEMENTED |
| Timestamped Names | MEDIUM | 6 lines | MEDIUM | NOT IMPLEMENTED |
| Number Conversion | MEDIUM | 15 lines | MEDIUM | NOT IMPLEMENTED |
| Recursive Merge | MEDIUM | 50 lines | MEDIUM | NOT IMPLEMENTED |
| File Upload Prep | MEDIUM | 40 lines | MEDIUM-LOW | NOT IMPLEMENTED |
| Content Extractor | LOW | 50 lines | LOW | PARTIALLY DONE |
| Pagination Helper | MEDIUM | 40 lines | MEDIUM | NOT IMPLEMENTED |
| Local Tokenizer | VERY LOW | 100+ lines | LOW | NOT IMPLEMENTED |

---

## Quick Win Recommendations

**For immediate implementation (~55 lines total, highest ROI):**

1. **Dict Path Navigation** - 25 lines, HIGH value for request building
2. **Number Type Conversion** - 15 lines, fixes function calling bugs
3. **Snake/Camel Converter** - 10 lines, improves compatibility
4. **Timestamped Names** - 6 lines, enables batch/cache naming

**These 4 utilities unlock significant functionality with minimal effort.**

---

## What Already Works Well

The Elixir implementation already has:
- ✅ Excellent resource name normalization (`ResourceNames`)
- ✅ Working text extraction (`extract_text`)
- ✅ Type conversions in request modules
- ✅ Content/Part helpers for building requests
- ✅ Model name validation and normalization

---

## Notes on Python Dependencies

The Python library includes advanced utilities that depend on external libraries:
- **SentencePiece tokenizer** (`local_tokenizer.py`) - Would need Rust NIF or external service
- **PIL Image conversion** - Elixir has `image` library alternatives
- **MCP tool adapters** - Elixir would need MCP client library

These are lower priority as they require significant external dependency management.

---

**Document Generated:** 2024-12-06
**Analysis Scope:** Python genai utilities vs Elixir helpers
**Methodology:** Function-by-function comparison
