defmodule Gemini.Types.RegisterFilesConfig do
  @moduledoc """
  Configuration for the register_files method.

  ## Example

      config = %Gemini.Types.RegisterFilesConfig{
        http_options: %{timeout: 60_000}
      }
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Configuration options for registering GCS files.

    - `http_options` - Optional HTTP options to override defaults
    """
    field(:http_options, map())
  end
end

defmodule Gemini.Types.RegisterFilesResponse do
  @moduledoc """
  Response from the register_files method.

  Contains the list of files that were registered with the Gemini file service.

  ## Example

      {:ok, response} = Gemini.APIs.Files.register_files(
        ["gs://bucket/file.pdf"],
        credentials: credentials
      )

      Enum.each(response.files, fn file ->
        IO.puts("Registered: \#{file.name} - \#{file.uri}")
      end)
  """

  use TypedStruct

  alias Gemini.Types.File

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response containing registered files.

    - `files` - List of File structs for the registered files
    """
    field(:files, [File.t()], default: [])
  end

  @doc """
  Creates a RegisterFilesResponse from API response.

  ## Parameters

  - `response` - Map from API response with string keys

  ## Examples

      response = %{"files" => [%{"name" => "files/abc", "uri" => "gs://bucket/file"}]}
      RegisterFilesResponse.from_api(response)
  """
  @spec from_api(map()) :: t()
  def from_api(%{"files" => files}) when is_list(files) do
    %__MODULE__{
      files: Enum.map(files, &File.from_api_response/1)
    }
  end

  def from_api(_), do: %__MODULE__{}
end
