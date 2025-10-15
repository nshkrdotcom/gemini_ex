# Embeddings

Embeddings are a numerical representation of text input that open up a number of unique use cases, such as clustering, similarity measurement and information retrieval. For an introduction, check out the Embeddings guide.

## Method: models.embedContent

Generates a text embedding vector from the input Content using the specified Gemini Embedding model.

### Endpoint

`post https://generativelanguage.googleapis.com/v1beta/{model=models/*}:embedContent`

### Path parameters

  * **model** (string): Required. The model's resource name. This serves as an ID for the Model to use. This name should match a model name returned by the `models.list` method. Format: `models/{model}`.

### Request body

The request body contains data with the following structure:

  * **content** (object (Content)): Required. The content to embed. Only the `parts.text` fields will be counted.
  * **taskType** (enum (TaskType)): Optional. Optional task type for which the embeddings will be used. Not supported on earlier models (models/embedding-001).
  * **title** (string): Optional. An optional title for the text. Only applicable when TaskType is `RETRIEVAL_DOCUMENT`. Note: Specifying a `title` for `RETRIEVAL_DOCUMENT` provides better quality embeddings for retrieval.
  * **outputDimensionality** (integer): Optional. Optional reduced dimension for the output embedding. If set, excessive values in the output embedding are truncated from the end. Supported by newer models since 2024 only. You cannot set this value if using the earlier model (models/embedding-001).

### Example request

```shell
curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=$GEMINI_API_KEY" \
-H 'Content-Type: application/json' \
-d '{"model": "models/text-embedding-004",    "content": {    "parts":[{      "text": "Hello world"}]}, }' 2> /dev/null | head
```

### Response body

The response to an `EmbedContentRequest`. If successful, the response body contains data with the following structure:

  * **embedding** (object (ContentEmbedding)): Output only. The embedding generated from the input content.

<!-- end list -->

```json
{
  "embedding": {
    object (ContentEmbedding)
  }
}
```

## Method: models.batchEmbedContents

Generates multiple embedding vectors from the input Content which consists of a batch of strings represented as `EmbedContentRequest` objects.

### Endpoint

`post https://generativelanguage.googleapis.com/v1beta/{model=models/*}:batchEmbedContents`

### Path parameters

  * **model** (string): Required. The model's resource name. This serves as an ID for the Model to use. This name should match a model name returned by the `models.list` method. Format: `models/{model}`.

### Request body

The request body contains data with the following structure:

  * **requests[]** (object (EmbedContentRequest)): Required. Embed requests for the batch. The model in each of these requests must match the model specified `BatchEmbedContentsRequest.model`.

### Example request

```shell
curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:batchEmbedContents?key=$GEMINI_API_KEY" \
-H 'Content-Type: application/json' \
-d '{"requests": [{      "model": "models/text-embedding-004",      "content": {      "parts":[{        "text": "What is the meaning of life?"}]}, },      {      "model": "models/text-embedding-004",      "content": {      "parts":[{        "text": "How much wood would a woodchuck chuck?"}]}, },      {      "model": "models/text-embedding-004",      "content": {      "parts":[{        "text": "How does the brain work?"}]}, }, ]}' 2> /dev/null | grep -C 5 values
```

### Response body

The response to a `BatchEmbedContentsRequest`. If successful, the response body contains data with the following structure:

  * **embeddings[]** (object (ContentEmbedding)): Output only. The embeddings for each request, in the same order as provided in the batch request.

<!-- end list -->

```json
{
  "embeddings": [
    {
      object (ContentEmbedding)
    }
  ]
}
```

## EmbedContentRequest

Request containing the Content for the model to embed.

  * **model** (string): Required. The model's resource name. This serves as an ID for the Model to use. This name should match a model name returned by the `models.list` method. Format: `models/{model}`.
  * **content** (object (Content)): Required. The content to embed. Only the `parts.text` fields will be counted.
  * **taskType** (enum (TaskType)): Optional. Optional task type for which the embeddings will be used. Not supported on earlier models (models/embedding-001).
  * **title** (string): Optional. An optional title for the text. Only applicable when TaskType is `RETRIEVAL_DOCUMENT`. Note: Specifying a `title` for `RETRIEVAL_DOCUMENT` provides better quality embeddings for retrieval.
  * **outputDimensionality** (integer): Optional. Optional reduced dimension for the output embedding. If set, excessive values in the output embedding are truncated from the end. Supported by newer models since 2024 only. You cannot set this value if using the earlier model (models/embedding-001).

<!-- end list -->

```json
{
  "model": string,
  "content": {
    object (Content)
  },
  "taskType": enum (TaskType),
  "title": string,
  "outputDimensionality": integer
}
```

## ContentEmbedding

A list of floats representing an embedding.

  * **values[]** (number): The embedding values.

<!-- end list -->

```json
{
  "values": [
    number
  ]
}
```

## TaskType

Type of task for which the embedding will be used.

>   * **TASK\_TYPE\_UNSPECIFIED**: Unset value, which will default to one of the other enum values.
>   * **RETRIEVAL\_QUERY**: Specifies the given text is a query in a search/retrieval setting.
>   * **RETRIEVAL\_DOCUMENT**: Specifies the given text is a document from the corpus being searched.
>   * **SEMANTIC\_SIMILARITY**: Specifies the given text will be used for STS.
>   * **CLASSIFICATION**: Specifies that the given text will be classified.
>   * **CLUSTERING**: Specifies that the embeddings will be used for clustering.
>   * **QUESTION\_ANSWERING**: Specifies that the given text will be used for question answering.
>   * **FACT\_VERIFICATION**: Specifies that the given text will be used for fact verification.
>   * **CODE\_RETRIEVAL\_QUERY**: Specifies that the given text will be used for code retrieval.
