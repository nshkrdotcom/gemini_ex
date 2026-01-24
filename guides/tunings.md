# Model Fine-Tuning Guide

This guide covers fine-tuning Gemini models using supervised learning on Vertex AI.

## Overview

Fine-tuning allows you to adapt Gemini models to your specific use case by training them on your custom datasets. This improves model performance for domain-specific tasks like customer support, code generation, content moderation, or specialized Q&A.

**Key Benefits:**
- Improved accuracy for domain-specific tasks
- Consistent output formatting and style
- Better understanding of domain terminology
- Reduced need for extensive prompting

## Prerequisites

### Required Setup

1. **Vertex AI Authentication** - Tuning is only available on Vertex AI
2. **Google Cloud Project** - Active GCP project with billing enabled
3. **Vertex AI API** - Enable the Vertex AI API in your project
4. **Cloud Storage** - GCS bucket for training data
5. **Permissions** - `Vertex AI User` or `Vertex AI Admin` role

### Supported Models

The following Gemini models support fine-tuning on Vertex AI:

- `gemini-2.5-pro-001` - Best quality, higher cost
- `gemini-2.5-flash-001` - Balanced quality and speed
- `gemini-2.5-flash-lite-001` - Fastest, most cost-effective

### Cost Considerations

Fine-tuning incurs costs based on:
- Training time (typically 1-4 hours)
- Base model size
- Number of training examples
- Number of epochs

Estimate costs using the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator).

## Quick Start

### 1. Prepare Training Data

Create a JSONL file with your training examples:

```jsonl
{"contents": [{"role": "user", "parts": [{"text": "What is your refund policy?"}]}, {"role": "model", "parts": [{"text": "We offer full refunds within 30 days of purchase with proof of receipt."}]}]}
{"contents": [{"role": "user", "parts": [{"text": "How do I track my order?"}]}, {"role": "model", "parts": [{"text": "Visit our tracking page at example.com/track and enter your order number."}]}]}
{"contents": [{"role": "user", "parts": [{"text": "Do you ship internationally?"}]}, {"role": "model", "parts": [{"text": "Yes, we ship to over 50 countries. Shipping times vary by destination."}]}]}
```

**Best Practices:**
- Minimum 100 examples recommended (more is better)
- Maximum 10,000 examples per job
- Balance your dataset across different topics
- Include diverse input phrasings
- Ensure consistent output quality

### 2. Upload to Cloud Storage

Upload your training data to GCS:

```bash
gsutil cp training-data.jsonl gs://my-bucket/tuning/training-data.jsonl
```

Optionally, create validation data:

```bash
gsutil cp validation-data.jsonl gs://my-bucket/tuning/validation-data.jsonl
```

### 3. Configure Authentication

Set up Vertex AI credentials:

```elixir
# Using environment variables
System.put_env("VERTEX_PROJECT_ID", "my-project-id")
System.put_env("VERTEX_LOCATION", "us-central1")
System.put_env("VERTEX_ACCESS_TOKEN", "ya29....")

# Or using application config
config :gemini, :vertex_ai,
  project_id: "my-project-id",
  location: "us-central1",
  access_token: "ya29...."
```

### 4. Create a Tuning Job

```elixir
alias Gemini.Types.Tuning.CreateTuningJobConfig
alias Gemini.APIs.Tunings

# Create job configuration
config = %CreateTuningJobConfig{
  base_model: "gemini-2.5-flash-001",
  tuned_model_display_name: "customer-support-model",
  training_dataset_uri: "gs://my-bucket/tuning/training-data.jsonl",
  validation_dataset_uri: "gs://my-bucket/tuning/validation-data.jsonl",
  epoch_count: 10,
  learning_rate_multiplier: 1.0
}

# Start tuning
{:ok, job} = Tunings.tune(config, auth: :vertex_ai)

IO.puts("Job created: #{job.name}")
IO.puts("State: #{job.state}")
```

### 5. Monitor Progress

Poll the job status periodically:

```elixir
# Manual polling
{:ok, job} = Tunings.get(job_name, auth: :vertex_ai)

case job.state do
  :job_state_succeeded ->
    IO.puts("Training complete!")
    IO.puts("Tuned model: #{job.tuned_model}")

  :job_state_running ->
    IO.puts("Still training...")

  :job_state_failed ->
    IO.puts("Training failed: #{job.error.message}")

  _ ->
    IO.puts("Current state: #{job.state}")
end

# Or use automatic waiting
{:ok, completed_job} = Tunings.wait_for_completion(
  job.name,
  poll_interval: 60_000,    # Check every minute
  timeout: 7_200_000,       # Wait up to 2 hours
  on_status: fn j ->
    IO.puts("State: #{j.state}")
  end,
  auth: :vertex_ai
)
```

### 6. Use the Tuned Model

Once training succeeds, use your tuned model:

```elixir
{:ok, response} = Gemini.generate(
  "What is your shipping policy?",
  model: completed_job.tuned_model,
  auth: :vertex_ai
)

IO.puts(response.text)
```

## Training Data Format

### Required Structure

Each line in your JSONL file must be a complete conversation:

```jsonl
{
  "contents": [
    {
      "role": "user",
      "parts": [{"text": "input text"}]
    },
    {
      "role": "model",
      "parts": [{"text": "expected output"}]
    }
  ]
}
```

### Multi-Turn Conversations

For multi-turn examples:

```jsonl
{
  "contents": [
    {"role": "user", "parts": [{"text": "Hello"}]},
    {"role": "model", "parts": [{"text": "Hi! How can I help you?"}]},
    {"role": "user", "parts": [{"text": "I need help with my order"}]},
    {"role": "model", "parts": [{"text": "I'd be happy to help. What's your order number?"}]}
  ]
}
```

### Validation Data

Create a separate validation set (10-20% of total data):

```elixir
config = %CreateTuningJobConfig{
  base_model: "gemini-2.5-flash-001",
  tuned_model_display_name: "my-model",
  training_dataset_uri: "gs://bucket/training.jsonl",
  validation_dataset_uri: "gs://bucket/validation.jsonl"  # Optional but recommended
}
```

## Hyperparameter Tuning

### Epoch Count

Number of times the model trains on the full dataset:

```elixir
config = %CreateTuningJobConfig{
  # ... other fields
  epoch_count: 15  # Default: 10, Range: 1-100
}
```

**Guidelines:**
- More epochs = better learning but risk overfitting
- Start with default (10) and adjust based on validation metrics
- Use validation data to detect overfitting

### Learning Rate Multiplier

Controls how quickly the model adapts:

```elixir
config = %CreateTuningJobConfig{
  # ... other fields
  learning_rate_multiplier: 0.5  # Default: 1.0, Range: 0.1-2.0
}
```

**Guidelines:**
- Lower (0.3-0.7) = more stable, slower convergence
- Higher (1.5-2.0) = faster convergence, risk of instability
- Start with 1.0 and adjust if needed

### Adapter Size

Model capacity for fine-tuning:

```elixir
config = %CreateTuningJobConfig{
  # ... other fields
  adapter_size: "ADAPTER_SIZE_FOUR"
}
```

**Options:**
- `"ADAPTER_SIZE_ONE"` - Smallest, fastest, least capacity
- `"ADAPTER_SIZE_FOUR"` - Balanced (default)
- `"ADAPTER_SIZE_EIGHT"` - Larger capacity
- `"ADAPTER_SIZE_SIXTEEN"` - Maximum capacity

**Guidelines:**
- Use larger adapters for complex tasks
- Start with default and increase if underfitting

## Managing Tuning Jobs

### List All Jobs

```elixir
# List recent jobs
{:ok, response} = Tunings.list(auth: :vertex_ai)

Enum.each(response.tuning_jobs, fn job ->
  IO.puts("#{job.tuned_model_display_name}: #{job.state}")
end)

# With pagination
{:ok, response} = Tunings.list(
  page_size: 50,
  page_token: response.next_page_token,
  auth: :vertex_ai
)

# Get all jobs automatically
{:ok, all_jobs} = Tunings.list_all(auth: :vertex_ai)
```

### Filter Jobs

```elixir
# Filter by state
{:ok, succeeded} = Tunings.list(
  filter: "state=JOB_STATE_SUCCEEDED",
  auth: :vertex_ai
)

# Filter by label
{:ok, production} = Tunings.list(
  filter: "labels.environment=production",
  auth: :vertex_ai
)
```

### Cancel Running Jobs

```elixir
{:ok, job} = Tunings.cancel(job_name, auth: :vertex_ai)

# Verify cancellation
{:ok, updated} = Tunings.get(job_name, auth: :vertex_ai)
assert updated.state in [:job_state_cancelling, :job_state_cancelled]
```

## Best Practices

### Data Quality

1. **Curate High-Quality Examples**
   - Review and validate each example
   - Remove duplicates and errors
   - Ensure consistent formatting

2. **Balance Your Dataset**
   - Equal representation of different topics
   - Diverse input phrasings
   - Consistent output style

3. **Use Validation Data**
   - Hold out 10-20% for validation
   - Helps detect overfitting
   - Provides performance metrics

### Training Strategy

1. **Start Simple**
   ```elixir
   # Initial training
   config = %CreateTuningJobConfig{
     base_model: "gemini-2.5-flash-001",
     tuned_model_display_name: "model-v1",
     training_dataset_uri: "gs://bucket/data.jsonl",
     epoch_count: 10,
     learning_rate_multiplier: 1.0
   }
   ```

2. **Iterate and Improve**
   - Test the tuned model
   - Collect failure cases
   - Add to training data
   - Retrain with updated data

3. **Monitor Metrics**
   ```elixir
   {:ok, job} = Tunings.get(job_name, auth: :vertex_ai)

   if job.tuning_data_stats do
     IO.inspect(job.tuning_data_stats, label: "Training Statistics")
   end
   ```

### Production Deployment

1. **Version Your Models**
   ```elixir
   tuned_model_display_name: "support-model-v2-#{Date.utc_today()}"
   ```

2. **Label Your Jobs**
   ```elixir
   config = %CreateTuningJobConfig{
     # ... other fields
     labels: %{
       "environment" => "production",
       "version" => "v2",
       "team" => "ml-ops"
     }
   }
   ```

3. **Test Before Deployment**
   - Validate on held-out test set
   - Compare with base model
   - A/B test in production

## Troubleshooting

### Common Issues

**"Training data not found"**
- Verify GCS URI is correct
- Check bucket permissions
- Ensure file is in JSONL format

**"Invalid training data format"**
- Validate each line is valid JSON
- Check `contents` structure
- Ensure proper `role` and `parts` fields

**"Insufficient training data"**
- Minimum 100 examples recommended
- Add more diverse examples
- Check for duplicates

**"Job failed during training"**
- Check error message in `job.error`
- Verify data quality
- Try reducing learning rate

### Getting Help

```elixir
# Check job error details
{:ok, job} = Tunings.get(job_name, auth: :vertex_ai)

if job.state == :job_state_failed do
  IO.puts("Error: #{job.error.message}")
  IO.puts("Code: #{job.error.code}")
  IO.inspect(job.error.details, label: "Details")
end
```

## Complete Example

```elixir
defmodule MyApp.ModelTuning do
  alias Gemini.Types.Tuning.CreateTuningJobConfig
  alias Gemini.APIs.Tunings

  def train_customer_support_model do
    # 1. Create configuration
    config = %CreateTuningJobConfig{
      base_model: "gemini-2.5-flash-001",
      tuned_model_display_name: "support-v1-#{Date.utc_today()}",
      training_dataset_uri: "gs://my-bucket/support-training.jsonl",
      validation_dataset_uri: "gs://my-bucket/support-validation.jsonl",
      epoch_count: 15,
      learning_rate_multiplier: 0.8,
      labels: %{"team" => "support", "version" => "v1"}
    }

    # 2. Start tuning
    {:ok, job} = Tunings.tune(config, auth: :vertex_ai)
    IO.puts("Started job: #{job.name}")

    # 3. Wait for completion
    {:ok, completed} = Tunings.wait_for_completion(
      job.name,
      poll_interval: 120_000,  # 2 minutes
      on_status: &log_progress/1,
      auth: :vertex_ai
    )

    # 4. Handle result
    case completed.state do
      :job_state_succeeded ->
        IO.puts("Success! Model: #{completed.tuned_model}")
        test_model(completed.tuned_model)

      :job_state_failed ->
        IO.puts("Failed: #{completed.error.message}")

      _ ->
        IO.puts("Unexpected state: #{completed.state}")
    end
  end

  defp log_progress(job) do
    IO.puts("[#{DateTime.utc_now()}] State: #{job.state}")

    if job.tuning_data_stats do
      IO.inspect(job.tuning_data_stats, label: "Stats")
    end
  end

  defp test_model(model_name) do
    test_prompts = [
      "What is your refund policy?",
      "How do I track my order?",
      "Do you ship internationally?"
    ]

    Enum.each(test_prompts, fn prompt ->
      {:ok, response} = Gemini.generate(prompt,
        model: model_name,
        auth: :vertex_ai
      )

      IO.puts("Q: #{prompt}")
      IO.puts("A: #{response.text}\n")
    end)
  end
end
```

## Additional Resources

- [Vertex AI Tuning Documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini-supervised-tuning)
- [Training Data Best Practices](https://cloud.google.com/vertex-ai/generative-ai/docs/models/tune-models)
- [Pricing Calculator](https://cloud.google.com/products/calculator)
- [Gemini Model Garden](https://cloud.google.com/vertex-ai/generative-ai/docs/learn/models)

## Next Steps

- Review [Rate Limiting & Cached Contexts](rate_limiting.md#cached-context-tokens) to reduce costs with tuned models
- Explore [Function Calling](function_calling.md) for enhanced capabilities
- Check [Streaming Guide](../../STREAMING.md) for real-time responses
