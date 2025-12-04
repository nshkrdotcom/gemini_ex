#!/usr/bin/env elixir
# K-Nearest Neighbors (K-NN) Classification with Embeddings Demo
#
# This example demonstrates how to use embeddings for text classification:
# 1. Create labeled training examples (different categories)
# 2. Embed all training examples using CLASSIFICATION task type
# 3. Embed new text to classify
# 4. Use K-NN algorithm to classify based on nearest neighbors
# 5. Evaluate classification confidence and accuracy
#
# This approach is particularly useful for:
# - Few-shot learning (classify with minimal training examples)
# - Dynamic categories (add new categories without retraining)
# - Semantic classification (understand concepts, not just keywords)
#
# Usage: mix run examples/use_cases/classification.exs

require Logger

alias Gemini.APIs.Coordinator
alias Gemini.Types.Response.{EmbedContentResponse, ContentEmbedding}

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("K-NN TEXT CLASSIFICATION WITH EMBEDDINGS")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
Embedding-based classification uses semantic similarity to categorize text:
• Few-shot learning: Classify with just a few examples per category
• No model training: Works immediately with example-based learning
• Flexible categories: Easy to add/modify categories dynamically
• Semantic understanding: Captures meaning beyond keywords
""")

# ============================================================================
# STEP 1: Create Training Set
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("STEP 1: CREATING TRAINING SET")
IO.puts(String.duplicate("-", 80) <> "\n")

# Training examples for customer support ticket classification
training_examples = [
  # Technical Support
  %{
    category: "technical_support",
    text: "My laptop won't turn on after the latest update. The power button doesn't respond."
  },
  %{
    category: "technical_support",
    text:
      "I'm getting an error message when trying to install the software. Error code 0x80070643."
  },
  %{
    category: "technical_support",
    text: "The application crashes every time I try to open a large file. Can you help?"
  },
  %{
    category: "technical_support",
    text: "WiFi keeps disconnecting on my device. I've tried restarting but it doesn't help."
  },
  # Billing/Payment
  %{
    category: "billing",
    text: "I was charged twice for my subscription this month. Can I get a refund?"
  },
  %{
    category: "billing",
    text: "How do I update my credit card information? The payment method expired."
  },
  %{
    category: "billing",
    text: "I'd like to cancel my subscription and get a prorated refund for this month."
  },
  %{
    category: "billing",
    text: "The invoice shows an incorrect amount. I should have received the student discount."
  },
  # Account Management
  %{
    category: "account",
    text: "I forgot my password and the reset email isn't arriving. What should I do?"
  },
  %{
    category: "account",
    text: "How do I change my email address associated with this account?"
  },
  %{
    category: "account",
    text: "I want to delete my account permanently and remove all my data."
  },
  %{
    category: "account",
    text: "Can I merge two accounts? I accidentally created a duplicate."
  },
  # Product Inquiry
  %{
    category: "product_inquiry",
    text: "What are the differences between the Basic and Premium plans?"
  },
  %{
    category: "product_inquiry",
    text: "Does your product support integration with Salesforce?"
  },
  %{
    category: "product_inquiry",
    text: "Is there a mobile app available for iOS and Android?"
  },
  %{
    category: "product_inquiry",
    text: "What's the maximum storage limit for the Enterprise plan?"
  }
]

categories =
  training_examples
  |> Enum.map(& &1.category)
  |> Enum.uniq()

IO.puts("Training set:")
IO.puts("  Total examples: #{length(training_examples)}")
IO.puts("  Categories: #{Enum.join(categories, ", ")}")
IO.puts("  Examples per category: #{div(length(training_examples), length(categories))}\n")

# ============================================================================
# STEP 2: Embed Training Examples
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("STEP 2: EMBEDDING TRAINING EXAMPLES")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts(
  "Embedding #{length(training_examples)} training examples using CLASSIFICATION task type..."
)

embedded_training =
  Enum.map(training_examples, fn example ->
    {:ok, %EmbedContentResponse{embedding: embedding}} =
      Coordinator.embed_content(
        example.text,
        model: "gemini-embedding-001",
        task_type: :classification,
        output_dimensionality: 768
      )

    normalized = ContentEmbedding.normalize(embedding)
    Map.put(example, :embedding, normalized)
  end)

IO.puts("✓ Training set embedded and normalized")

# Show category distribution
IO.puts("\nCategory distribution:")

Enum.each(categories, fn category ->
  count = Enum.count(embedded_training, fn ex -> ex.category == category end)
  bar = String.duplicate("█", count * 2)
  IO.puts("  #{String.pad_trailing(category, 20)} #{count} #{bar}")
end)

# ============================================================================
# STEP 3: Test Classification
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 3: CLASSIFYING NEW TEXTS")
IO.puts(String.duplicate("-", 80) <> "\n")

# Test examples (without labels)
test_examples = [
  "The app freezes when I try to export data. Is this a known bug?",
  "I need to upgrade my plan to get more storage. How do I do that?",
  "Can I get a copy of my receipt from last month's payment?",
  "My username is already taken. Can I recover my old account?",
  "What file formats does your software support for import?"
]

defmodule KNN do
  @moduledoc """
  K-Nearest Neighbors classifier using embedding similarity.
  """

  @doc """
  Classify text using K-NN based on cosine similarity.
  Returns {predicted_category, confidence, top_k_neighbors}.
  """
  def classify(text_embedding, training_set, k \\ 3) do
    # Find K nearest neighbors
    neighbors =
      training_set
      |> Enum.map(fn example ->
        similarity = ContentEmbedding.cosine_similarity(text_embedding, example.embedding)
        {example, similarity}
      end)
      |> Enum.sort_by(fn {_example, similarity} -> similarity end, :desc)
      |> Enum.take(k)

    # Vote by category (weighted by similarity)
    category_votes =
      neighbors
      |> Enum.reduce(%{}, fn {example, similarity}, acc ->
        Map.update(acc, example.category, similarity, &(&1 + similarity))
      end)

    # Get predicted category
    {predicted_category, total_vote} = Enum.max_by(category_votes, fn {_cat, vote} -> vote end)

    # Calculate confidence (proportion of votes for winning category)
    total_similarity = Enum.reduce(neighbors, 0, fn {_ex, sim}, acc -> acc + sim end)
    confidence = total_vote / total_similarity

    {predicted_category, confidence, neighbors}
  end
end

IO.puts("Classifying test examples with K=3 nearest neighbors:\n")

test_results =
  Enum.map(test_examples, fn text ->
    # Embed the test text
    {:ok, %EmbedContentResponse{embedding: embedding}} =
      Coordinator.embed_content(
        text,
        model: "gemini-embedding-001",
        task_type: :classification,
        output_dimensionality: 768
      )

    embedding = ContentEmbedding.normalize(embedding)

    # Classify using K-NN
    {predicted_category, confidence, neighbors} =
      KNN.classify(embedding, embedded_training, 3)

    {text, predicted_category, confidence, neighbors}
  end)

# Display results
Enum.each(test_results, fn {text, category, confidence, neighbors} ->
  IO.puts(String.duplicate("-", 80))
  IO.puts("Text: \"#{text}\"")
  IO.puts("\nPredicted: #{category} (confidence: #{Float.round(confidence * 100, 1)}%)")
  IO.puts("\nTop 3 nearest neighbors:")

  Enum.each(neighbors, fn {example, similarity} ->
    IO.puts("  • [#{Float.round(similarity, 4)}] #{example.category}")
    IO.puts("    \"#{String.slice(example.text, 0..70)}...\"")
  end)

  IO.puts("")
end)

# ============================================================================
# STEP 4: Evaluation with Labeled Test Set
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("STEP 4: ACCURACY EVALUATION")
IO.puts(String.duplicate("-", 80) <> "\n")

# Labeled test set for evaluation
labeled_test = [
  %{text: "Error 404 when accessing my dashboard", expected: "technical_support"},
  %{text: "Refund for accidental double payment", expected: "billing"},
  %{text: "Reset my two-factor authentication", expected: "account"},
  %{text: "Does it work with Google Workspace?", expected: "product_inquiry"},
  %{text: "Connection timeout error", expected: "technical_support"},
  %{text: "Subscription renewal charges", expected: "billing"},
  %{text: "Change my phone number", expected: "account"},
  %{text: "API rate limits for Enterprise", expected: "product_inquiry"}
]

IO.puts("Evaluating on #{length(labeled_test)} labeled test examples:\n")

evaluation_results =
  Enum.map(labeled_test, fn test ->
    {:ok, %EmbedContentResponse{embedding: embedding}} =
      Coordinator.embed_content(
        test.text,
        model: "gemini-embedding-001",
        task_type: :classification,
        output_dimensionality: 768
      )

    embedding = ContentEmbedding.normalize(embedding)
    {predicted, confidence, _neighbors} = KNN.classify(embedding, embedded_training, 3)

    correct = predicted == test.expected
    {test, predicted, confidence, correct}
  end)

# Display evaluation results
Enum.each(evaluation_results, fn {test, predicted, confidence, correct} ->
  marker = if correct, do: "✓", else: "✗"
  status = if correct, do: "CORRECT", else: "WRONG"

  IO.puts(
    "#{marker} #{status} | Expected: #{test.expected}, Predicted: #{predicted} (#{Float.round(confidence * 100, 1)}%)"
  )

  IO.puts("   \"#{test.text}\"")
end)

# Calculate accuracy
accuracy =
  evaluation_results
  |> Enum.count(fn {_test, _pred, _conf, correct} -> correct end)
  |> Kernel./(length(labeled_test))
  |> Kernel.*(100)

IO.puts("\n#{String.duplicate("=", 80)}")

IO.puts(
  "ACCURACY: #{Float.round(accuracy, 1)}% (#{round(accuracy * length(labeled_test) / 100)}/#{length(labeled_test)} correct)"
)

IO.puts(String.duplicate("=", 80))

# ============================================================================
# STEP 5: Confidence Analysis
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 5: CONFIDENCE ANALYSIS")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("Confidence distribution across all predictions:\n")

# Group by confidence ranges
confidence_ranges = [
  {0.90, 1.00, "Very High (90-100%)"},
  {0.75, 0.90, "High (75-90%)"},
  {0.60, 0.75, "Medium (60-75%)"},
  {0.0, 0.60, "Low (<60%)"}
]

all_confidences =
  evaluation_results |> Enum.map(fn {_test, _pred, conf, _correct} -> conf end)

Enum.each(confidence_ranges, fn {min, max, label} ->
  count = Enum.count(all_confidences, fn conf -> conf >= min and conf < max end)
  bar = String.duplicate("█", count * 3)
  IO.puts("  #{String.pad_trailing(label, 25)} #{count} #{bar}")
end)

avg_confidence =
  Enum.sum(all_confidences) / length(all_confidences) * 100

IO.puts("\nAverage confidence: #{Float.round(avg_confidence, 1)}%")

# ============================================================================
# DEMONSTRATION: Adding New Category
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("DEMONSTRATION: ADDING NEW CATEGORY DYNAMICALLY")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
One advantage of embedding-based classification: easily add new categories
without retraining a model. Just add new examples and re-run classification!
""")

# Add new category: Feature Request
new_examples = [
  %{
    category: "feature_request",
    text: "It would be great to have dark mode in the mobile app."
  },
  %{
    category: "feature_request",
    text: "Please add support for exporting data to CSV format."
  },
  %{
    category: "feature_request",
    text: "Can you implement two-factor authentication via SMS?"
  }
]

IO.puts("Adding 'feature_request' category with #{length(new_examples)} examples...")

extended_training =
  embedded_training ++
    Enum.map(new_examples, fn example ->
      {:ok, %EmbedContentResponse{embedding: embedding}} =
        Coordinator.embed_content(
          example.text,
          model: "gemini-embedding-001",
          task_type: :classification,
          output_dimensionality: 768
        )

      normalized = ContentEmbedding.normalize(embedding)
      Map.put(example, :embedding, normalized)
    end)

IO.puts("✓ Extended training set created (#{length(extended_training)} total examples)\n")

# Test with feature request
test_feature = "Add keyboard shortcuts for common actions"
IO.puts("Testing: \"#{test_feature}\"")

{:ok, %EmbedContentResponse{embedding: test_emb}} =
  Coordinator.embed_content(
    test_feature,
    model: "gemini-embedding-001",
    task_type: :classification,
    output_dimensionality: 768
  )

test_emb = ContentEmbedding.normalize(test_emb)

{predicted, confidence, neighbors} = KNN.classify(test_emb, extended_training, 3)

IO.puts("Predicted: #{predicted} (confidence: #{Float.round(confidence * 100, 1)}%)")
IO.puts("\nTop neighbors:")

Enum.each(neighbors, fn {example, similarity} ->
  IO.puts("  • [#{Float.round(similarity, 4)}] #{example.category}")
end)

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("KEY TAKEAWAYS:")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
1. Embedding-based K-NN enables few-shot text classification
2. Use CLASSIFICATION task type for optimal embeddings
3. Normalize embeddings before computing similarity (non-3072 dimensions)
4. K=3 to 5 typically works well for K-NN classification
5. Confidence based on vote distribution provides uncertainty estimates
6. Easy to add new categories without retraining models
7. Works well with limited training data (few-shot learning)
8. Consider using 768 dimensions for efficient classification at scale
9. Higher confidence = more agreement among nearest neighbors
10. Semantic understanding allows generalization beyond keyword matching
""")

IO.puts(String.duplicate("=", 80) <> "\n")
