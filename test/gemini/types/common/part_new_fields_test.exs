defmodule Gemini.Types.PartNewFieldsTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.{FileData, FunctionResponse, Part}

  test "Part struct supports file_data, function_response, and thought" do
    file_data = %FileData{file_uri: "gs://bucket/file.pdf", mime_type: "application/pdf"}
    func_resp = %FunctionResponse{name: "lookup", response: %{"result" => "ok"}}

    part = %Part{
      text: "hello",
      file_data: file_data,
      function_response: func_resp,
      thought: true
    }

    assert part.file_data == file_data
    assert part.function_response == func_resp
    assert part.thought == true
  end

  test "__test_format_part__/1 emits camelCase keys for new fields" do
    file_data = %FileData{file_uri: "gs://bucket/file.pdf", mime_type: "application/pdf"}
    func_resp = %FunctionResponse{name: "lookup", response: %{"result" => "ok"}}

    api_part =
      Coordinator.__test_format_part__(%Part{
        file_data: file_data,
        function_response: func_resp,
        thought: true
      })

    assert api_part[:fileData] == %{
             "fileUri" => "gs://bucket/file.pdf",
             "mimeType" => "application/pdf"
           }

    assert api_part[:functionResponse]["name"] == "lookup"
    assert api_part[:functionResponse]["response"] == %{"result" => "ok"}
    assert api_part[:thought] == true
  end
end
