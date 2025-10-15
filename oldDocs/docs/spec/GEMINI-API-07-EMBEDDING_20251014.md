# Embeddings

The Gemini API offers text embedding models to generate embeddings for words, phrases, sentences, and code. These foundational embeddings power advanced NLP tasks such as semantic search, classification, and clustering, providing more accurate, context-aware results than keyword-based approaches.

Building Retrieval Augmented Generation (RAG) systems is a common use case for embeddings. Embeddings play a key role in significantly enhancing model outputs with improved factual accuracy, coherence, and contextual richness. They efficiently retrieve relevant information from knowledge bases, represented by embeddings, which are then passed as additional context in the input prompt to language models, guiding it to generate more informed and accurate responses.

To learn more about the available embedding model variants, see the [Model versions](#model-versions) section. For higher throughput serving at half the price, try Batch API Embedding.

## Generating embeddings
Use the `embedContent` method to generate text embeddings:

**Python**
**JavaScript**
**Go**
**REST**

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent" \
-H "x-goog-api-key: $GEMINI_API_KEY" \
-H 'Content-Type: application/json' \
-d '{"model": "models/gemini-embedding-001",
     "content": {"parts":[{"text": "What is the meaning of life?"}]}
    }'
```

You can also generate embeddings for multiple chunks at once by passing them in as a list of strings.

**Python**
**JavaScript**
**Go**
**REST**

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents" \
-H "x-goog-api-key: $GEMINI_API_KEY" \
-H 'Content-Type: application/json' \
-d '{"requests": [{
    "model": "models/gemini-embedding-001",
    "content": {
    "parts":[{
        "text": "What is the meaning of life?"}]}, },
    {
    "model": "models/gemini-embedding-001",
    "content": {
    "parts":[{
        "text": "How much wood would a woodchuck chuck?"}]}, },
    {
    "model": "models/gemini-embedding-001",
    "content": {
    "parts":[{
        "text": "How does the brain work?"}]}, }, ]}' 2> /dev/null | grep -C 5 values
```

## Specify task type to improve performance
You can use embeddings for a wide range of tasks from classification to document search. Specifying the right task type helps optimize the embeddings for the intended relationships, maximizing accuracy and efficiency. For a complete list of supported task types, see the [Supported task types table](#supported-task-types).

The following example shows how you can use `SEMANTIC_SIMILARITY` to check how similar in meaning strings of texts are.

> **Note:** Cosine similarity is a good distance metric because it focuses on direction rather than magnitude, which more accurately reflects conceptual closeness. Values range from -1 (opposite) to 1 (greatest similarity).

**Python**
**JavaScript**
**Go**
**REST**

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent" \
-H "x-goog-api-key: $GEMINI_API_KEY" \
-H 'Content-Type: application/json' \
-d '{"task_type": "SEMANTIC_SIMILARITY",
    "content": {
    "parts":[{
    "text": "What is the meaning of life?"}, {"text": "How much wood would a woodchuck chuck?"}, {"text": "How does the brain work?"}]}
    }'
```

The following shows an example output from this code snippet:

```
Similarity between 'What is the meaning of life?' and 'What is the purpose of existence?': 0.9481

Similarity between 'What is the meaning of life?' and 'How do I bake a cake?': 0.7471

Similarity between 'What is the purpose of existence?' and 'How do I bake a cake?': 0.7371
```

### Supported task types

| Task type | Description | Examples |
| :--- | :--- | :--- |
| **SEMANTIC_SIMILARITY** | Embeddings optimized to assess text similarity. | Recommendation systems, duplicate detection |
| **CLASSIFICATION** | Embeddings optimized to classify texts according to preset labels. | Sentiment analysis, spam detection |
| **CLUSTERING** | Embeddings optimized to cluster texts based on their similarities. | Document organization, market research, anomaly detection |
| **RETRIEVAL_DOCUMENT** | Embeddings optimized for document search. | Indexing articles, books, or web pages for search. |
| **RETRIEVAL_QUERY** | Embeddings optimized for general search queries. Use `RETRIEVAL_QUERY` for queries; `RETRIEVAL_DOCUMENT` for documents to be retrieved. | Custom search |
| **CODE_RETRIEVAL_QUERY** | Embeddings optimized for retrieval of code blocks based on natural language queries. Use `CODE_RETRIEVAL_QUERY` for queries; `RETRIEVAL_DOCUMENT` for code blocks to be retrieved. | Code suggestions and search |
| **QUESTION_ANSWERING** | Embeddings for questions in a question-answering system, optimized for finding documents that answer the question. Use `QUESTION_ANSWERING` for questions; `RETRIEVAL_DOCUMENT` for documents to be retrieved. | Chatbox |
| **FACT_VERIFICATION** | Embeddings for statements that need to be verified, optimized for retrieving documents that contain evidence supporting or refuting the statement. Use `FACT_VERIFICATION` for the target text; `RETRIEVAL_DOCUMENT` for documents to be retrieved | Automated fact-checking systems |

## Controlling embedding size
The Gemini embedding model, `gemini-embedding-001`, is trained using the Matryoshka Representation Learning (MRL) technique which teaches a model to learn high-dimensional embeddings that have initial segments (or prefixes) which are also useful, simpler versions of the same data.

Use the `output_dimensionality` parameter to control the size of the output embedding vector. Selecting a smaller output dimensionality can save storage space and increase computational efficiency for downstream applications, while sacrificing little in terms of quality. By default, it outputs a 3072-dimensional embedding, but you can truncate it to a smaller size without losing quality to save storage space. We recommend using 768, 1536, or 3072 output dimensions.

**Python**
**JavaScript**
**Go**
**REST**

```bash
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H 'Content-Type: application/json' \
    -d '{
        "content": {"parts":[{ "text": "What is the meaning of life?"}]},
        "output_dimensionality": 768
    }'
```

Example output from the code snippet:

```
Length of embedding: 768
```

### Ensuring quality for smaller dimensions
The 3072 dimension embedding is normalized. Normalized embeddings produce more accurate semantic similarity by comparing vector direction, not magnitude. For other dimensions, including 768 and 1536, you need to normalize the embeddings as follows:

**Python**

```python
import numpy as np
from numpy.linalg import norm

embedding_values_np = np.array(embedding_obj.values)
normed_embedding = embedding_values_np / np.linalg.norm(embedding_values_np)

print(f"Normed embedding length: {len(normed_embedding)}")
print(f"Norm of normed embedding: {np.linalg.norm(normed_embedding):.6f}") # Should be very close to 1
```

Example output from this code snippet:

```
Normed embedding length: 768
Norm of normed embedding: 1.000000
```

The following table shows the MTEB scores, a commonly used benchmark for embeddings, for different dimensions. Notably, the result shows that performance is not strictly tied to the size of the embedding dimension, with lower dimensions achieving scores comparable to their higher dimension counterparts.

| MRL Dimension | MTEB Score |
| :--- | :--- |
| 2048 | 68.16 |
| 1536 | 68.17 |
| 768 | 67.99 |
| 512 | 67.55 |
| 256 | 66.19 |
| 128 | 63.31 |

## Use cases
Text embeddings are crucial for a variety of common AI use cases, such as:

*   **Retrieval-Augmented Generation (RAG):** Embeddings enhance the quality of generated text by retrieving and incorporating relevant information into the context of a model.
*   **Information retrieval:** Search for the most semantically similar text or documents given a piece of input text.
    *   Document search tutorial task
*   **Search reranking:** Prioritize the most relevant items by semantically scoring initial results against the query.
    *   Search reranking tutorial task
*   **Anomaly detection:** Comparing groups of embeddings can help identify hidden trends or outliers.
    *   Anomaly detection tutorial bubble_chart
*   **Classification:** Automatically categorize text based on its content, such as sentiment analysis or spam detection
    *   Classification tutorial token
*   **Clustering:** Effectively grasp complex relationships by creating clusters and visualizations of your embeddings.
    *   Clustering visualization tutorial bubble_chart

## Storing embeddings
As you take embeddings to production, it is common to use vector databases to efficiently store, index, and retrieve high-dimensional embeddings. Google Cloud offers managed data services that can be used for this purpose including BigQuery, AlloyDB, and Cloud SQL.

The following tutorials show how to use other third party vector databases with Gemini Embedding.

*   ChromaDB tutorials bolt
*   QDrant tutorials bolt
*   Weaviate tutorials bolt
*   Pinecone tutorials bolt

## Model versions

| Property | Description |
| :--- | :--- |
| **Model code** | |
| Gemini API | `gemini-embedding-001` |
| **Supported data types** | |
| Input | Text |
| Output | Text embeddings |
| **Token limits**[*] | |
| Input token limit | 2,048 |
| Output dimension size | Flexible, supports: 128 - 3072, Recommended: 768, 1536, 3072 |
| **Versions** | Read the model version patterns for more details. |
| Stable | `gemini-embedding-001` |
| Experimental | `gemini-embedding-exp-03-07` (deprecating in Oct of 2025) |
| **Latest update** | June 2025 |

## Batch embeddings
If latency is not a concern, try using the Gemini Embeddings model with Batch API. This allows for much higher throughput at 50% of interactive Embedding pricing. Find examples on how to get started in the Batch API cookbook.

## Responsible use notice
Unlike generative AI models that create new content, the Gemini Embedding model is only intended to transform the format of your input data into a numerical representation. While Google is responsible for providing an embedding model that transforms the format of your input data to the numerical-format requested, users retain full responsibility for the data they input and the resulting embeddings. By using the Gemini Embedding model you confirm that you have the necessary rights to any content that you upload. Do not generate content that infringes on others' intellectual property or privacy rights. Your use of this service is subject to our Prohibited Use Policy and Google's Terms of Service.

## Start building with embeddings
Check out the embeddings quickstart notebook to explore the model capabilities and learn how to customize and visualize your embeddings.

## Deprecation notice for legacy models
The following models will be deprecated in October, 2025: - `embedding-001` - `embedding-gecko-001` - `gemini-embedding-exp-03-07` (`gemini-embedding-exp`)

