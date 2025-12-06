# Application Default Credentials (ADC) Guide

This guide explains how to use Application Default Credentials (ADC) with the Gemini Elixir client for Google Cloud authentication.

## Overview

Application Default Credentials (ADC) is a strategy used by Google Cloud client libraries to automatically find credentials based on the application environment. ADC provides a simple and consistent way to authenticate with Google Cloud APIs without hardcoding credentials in your application.

## How ADC Works

ADC searches for credentials in the following order:

1. **Environment Variable**: `GOOGLE_APPLICATION_CREDENTIALS` pointing to a service account JSON file
2. **User Credentials**: `~/.config/gcloud/application_default_credentials.json` (created via `gcloud auth application-default login`)
3. **GCP Metadata Server**: Automatic credentials for code running on Google Cloud Platform infrastructure

## Benefits

- **Environment-aware authentication**: Automatically uses the right credentials based on where your code runs
- **Simplified deployment**: No need to manage credentials differently for development vs. production
- **Secure**: Avoids hardcoding credentials in source code
- **Standardized**: Follows Google Cloud's recommended authentication practices
- **Automatic token refresh**: Handles token expiration and renewal automatically
- **Token caching**: Reduces API calls by caching access tokens with automatic expiration

## Setting Up ADC

### Option 1: Service Account Key File (Development & CI/CD)

Best for: Local development, testing, CI/CD pipelines

1. Create a service account in Google Cloud Console
2. Download the JSON key file
3. Set the environment variable:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

**Example usage:**

```elixir
# ADC will automatically find and use the service account
{:ok, creds} = Gemini.Auth.ADC.load_credentials()
{:ok, token} = Gemini.Auth.ADC.get_access_token(creds)

# Use with Vertex AI
{:ok, project_id} = Gemini.Auth.ADC.get_project_id(creds)

config = %{
  project_id: project_id,
  location: "us-central1"
}

{:ok, response} = Gemini.generate("Hello!", auth: :vertex_ai)
```

**Security Note**: Never commit service account keys to version control. Use environment variables or secret management systems.

### Option 2: User Credentials (Development)

Best for: Local development with personal Google account

1. Install and configure the gcloud CLI
2. Run the ADC login command:

```bash
gcloud auth application-default login
```

This creates a credentials file at `~/.config/gcloud/application_default_credentials.json`.

**Example usage:**

```elixir
# ADC will automatically find and use your user credentials
{:ok, creds} = Gemini.Auth.ADC.load_credentials()
{:ok, token} = Gemini.Auth.ADC.get_access_token(creds)

# User credentials may include quota_project_id
case Gemini.Auth.ADC.get_project_id(creds) do
  {:ok, project_id} ->
    IO.puts("Using project: #{project_id}")
  {:error, _} ->
    # Set project ID explicitly if not in user credentials
    config = %{project_id: "my-project-id", location: "us-central1"}
end
```

**Revoke access** when done:

```bash
gcloud auth application-default revoke
```

### Option 3: GCP Metadata Server (Production)

Best for: Production deployments on Google Cloud Platform

Works automatically on:
- **Compute Engine** VMs
- **Google Kubernetes Engine** (GKE) pods
- **Cloud Run** services
- **Cloud Functions**
- **App Engine** applications

**No setup required!** Just deploy your application to GCP.

**Example usage:**

```elixir
# On GCP, ADC automatically uses the metadata server
{:ok, creds} = Gemini.Auth.ADC.load_credentials()

# Automatically retrieves project ID from metadata
{:ok, project_id} = Gemini.Auth.ADC.get_project_id(creds)

# Token is fetched from metadata server
{:ok, token} = Gemini.Auth.ADC.get_access_token(creds)

# Ready to use with Vertex AI
{:ok, response} = Gemini.generate("Hello from Cloud Run!", auth: :vertex_ai)
```

**Service Account Permissions**: Ensure the Compute Engine default service account or your custom service account has the necessary permissions (e.g., `Vertex AI User` role).

## Using ADC in Your Application

### Basic Usage

```elixir
defmodule MyApp.GeminiClient do
  alias Gemini.Auth.ADC

  def call_gemini(prompt) do
    with {:ok, creds} <- ADC.load_credentials(),
         {:ok, token} <- ADC.get_access_token(creds),
         {:ok, project_id} <- ADC.get_project_id(creds) do

      # Use credentials with Vertex AI
      Gemini.generate(
        prompt,
        auth: :vertex_ai,
        project_id: project_id,
        location: "us-central1"
      )
    else
      {:error, reason} ->
        {:error, "Authentication failed: #{reason}"}
    end
  end
end
```

### Integration with Vertex AI Strategy

The Vertex AI authentication strategy automatically falls back to ADC when no explicit credentials are provided:

```elixir
# If you provide project_id and location but no credentials,
# VertexStrategy will automatically try ADC
config = %{
  project_id: "my-project",
  location: "us-central1"
}

{:ok, response} = Gemini.generate("Hello!", auth: :vertex_ai)
```

### Checking ADC Availability

```elixir
if Gemini.Auth.ADC.available?() do
  IO.puts("ADC credentials are available")
  {:ok, creds} = Gemini.Auth.ADC.load_credentials()
  # Use credentials...
else
  IO.puts("No ADC credentials found")
  # Fall back to explicit credentials or show error
end
```

### Getting Project Information

```elixir
{:ok, creds} = Gemini.Auth.ADC.load_credentials()

case Gemini.Auth.ADC.get_project_id(creds) do
  {:ok, project_id} ->
    IO.puts("Project ID: #{project_id}")

  {:error, _} ->
    # Some credential types don't include project ID
    # Use environment variable or prompt user
    project_id = System.get_env("VERTEX_PROJECT_ID") || "default-project"
end
```

## Token Caching

ADC automatically caches access tokens to reduce API calls and improve performance.

### How Caching Works

- **Automatic caching**: Tokens are cached after generation
- **Expiration handling**: Tokens are refreshed before they expire
- **Refresh buffer**: Tokens are refreshed 5 minutes before expiration (configurable)
- **Thread-safe**: Uses ETS for concurrent access

### Cache Behavior

```elixir
{:ok, creds} = Gemini.Auth.ADC.load_credentials()

# First call generates and caches token
{:ok, token1} = Gemini.Auth.ADC.get_access_token(creds)

# Second call uses cached token (no API call)
{:ok, token2} = Gemini.Auth.ADC.get_access_token(creds)

# Tokens are the same
token1 == token2  # => true
```

### Force Token Refresh

```elixir
{:ok, creds} = Gemini.Auth.ADC.load_credentials()

# Force a fresh token (bypasses cache)
{:ok, fresh_token} = Gemini.Auth.ADC.refresh_token(creds)

# Or use the force_refresh option
{:ok, fresh_token} = Gemini.Auth.ADC.get_access_token(creds, force_refresh: true)
```

### Custom Cache Keys

```elixir
# Use custom cache key for separate token pools
{:ok, creds} = Gemini.Auth.ADC.load_credentials()

{:ok, token} = Gemini.Auth.ADC.get_access_token(
  creds,
  cache_key: "my_app_vertex_ai"
)
```

## Troubleshooting

### No Credentials Found

**Error**: `"No credentials found via ADC"`

**Solutions**:

1. **Set GOOGLE_APPLICATION_CREDENTIALS**:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
   ```

2. **Run gcloud auth**:
   ```bash
   gcloud auth application-default login
   ```

3. **Check if on GCP**:
   ```elixir
   Gemini.Auth.MetadataServer.available?()
   ```

### Invalid Service Account File

**Error**: `"Failed to parse JSON"` or `"Invalid service account file format"`

**Solutions**:

- Verify the file is valid JSON
- Ensure it's a service account key (has `"type": "service_account"`)
- Download a fresh key from Google Cloud Console
- Check file permissions (must be readable)

### Token Generation Fails

**Error**: `"Failed to generate access token"`

**Solutions**:

1. **Service Account**: Verify the service account has necessary permissions
2. **User Credentials**: Re-authenticate with `gcloud auth application-default login`
3. **Metadata Server**: Check if running on GCP and service account is properly configured

### Project ID Not Available

**Error**: `"No project ID available in credentials"`

**Solutions**:

1. **Explicitly set project ID**:
   ```elixir
   config = %{
     project_id: "my-project-id",
     location: "us-central1"
   }
   ```

2. **Use environment variable**:
   ```bash
   export VERTEX_PROJECT_ID="my-project-id"
   ```

3. **For user credentials**: Specify quota_project_id during gcloud auth

### Metadata Server Timeout

**Error**: `"Failed to contact metadata server"`

**Solutions**:

- Verify you're running on GCP infrastructure
- Check network connectivity
- Ensure metadata server is not blocked by firewall
- Verify service account is attached to the instance

## Best Practices

### 1. Environment-Specific Credentials

Use different credential sources for different environments:

```elixir
defmodule MyApp.Config do
  def get_credentials do
    case Mix.env() do
      :prod ->
        # Production: Use metadata server on GCP
        if Gemini.Auth.MetadataServer.available?() do
          Gemini.Auth.ADC.load_credentials()
        else
          {:error, "Production must run on GCP"}
        end

      :dev ->
        # Development: Use service account or user credentials
        Gemini.Auth.ADC.load_credentials()

      :test ->
        # Test: Use test credentials or mocks
        {:ok, {:service_account, test_credentials()}}
    end
  end
end
```

### 2. Credential Validation at Startup

Validate credentials when your application starts:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Initialize token cache
    Gemini.Auth.TokenCache.init()

    # Validate ADC on startup
    case Gemini.Auth.ADC.load_credentials() do
      {:ok, creds} ->
        Logger.info("ADC credentials loaded successfully")

        case Gemini.Auth.ADC.get_access_token(creds) do
          {:ok, _token} ->
            Logger.info("Successfully authenticated with ADC")
          {:error, reason} ->
            Logger.warning("ADC token generation failed: #{reason}")
        end

      {:error, reason} ->
        Logger.warning("ADC not available: #{reason}")
    end

    # Start your application...
    children = [...]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

### 3. Error Handling

Always handle credential errors gracefully:

```elixir
defmodule MyApp.GeminiClient do
  def generate_with_retry(prompt, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)

    generate_with_retry_impl(prompt, opts, max_retries)
  end

  defp generate_with_retry_impl(prompt, opts, retries) when retries > 0 do
    case Gemini.generate(prompt, opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, "Failed to get access token" <> _} when retries > 1 ->
        # Token might be expired, force refresh
        Logger.info("Refreshing ADC token and retrying...")

        with {:ok, creds} <- Gemini.Auth.ADC.load_credentials(),
             {:ok, _token} <- Gemini.Auth.ADC.refresh_token(creds) do
          generate_with_retry_impl(prompt, opts, retries - 1)
        else
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_with_retry_impl(_prompt, _opts, 0) do
    {:error, "Max retries exceeded"}
  end
end
```

### 4. Secure Credential Storage

Never commit credentials to version control:

```bash
# .gitignore
*.json
!config/*.json.example
.env
.env.local
```

Use environment variables or secret management:

```bash
# .env.example (commit this)
GOOGLE_APPLICATION_CREDENTIALS=/path/to/your/service-account-key.json
VERTEX_PROJECT_ID=your-project-id
VERTEX_LOCATION=us-central1
```

### 5. Monitoring and Logging

Monitor ADC credential usage:

```elixir
defmodule MyApp.Telemetry do
  require Logger

  def handle_event([:gemini, :auth, :adc, :token_cached], measurements, metadata, _config) do
    Logger.debug("ADC token cached",
      ttl: measurements.ttl,
      credential_type: metadata.credential_type
    )
  end

  def handle_event([:gemini, :auth, :adc, :token_refreshed], _measurements, metadata, _config) do
    Logger.info("ADC token refreshed",
      credential_type: metadata.credential_type,
      source: metadata.source
    )
  end
end
```

## Examples

### Complete Application Example

```elixir
defmodule MyApp.VertexAI do
  @moduledoc """
  Vertex AI client using Application Default Credentials.
  """

  alias Gemini.Auth.ADC
  require Logger

  @default_location "us-central1"

  def generate(prompt, opts \\ []) do
    with {:ok, creds} <- get_credentials(),
         {:ok, token} <- ADC.get_access_token(creds),
         {:ok, project_id} <- get_project_id(creds) do

      location = Keyword.get(opts, :location, @default_location)
      model = Keyword.get(opts, :model, "gemini-2.0-flash-lite")

      Gemini.generate(
        prompt,
        auth: :vertex_ai,
        project_id: project_id,
        location: location,
        model: model
      )
    else
      {:error, reason} = error ->
        Logger.error("Vertex AI generation failed: #{reason}")
        error
    end
  end

  defp get_credentials do
    case ADC.load_credentials() do
      {:ok, creds} = success ->
        success

      {:error, reason} ->
        Logger.error("Failed to load ADC credentials: #{reason}")
        {:error, "Authentication required. Please set up Application Default Credentials."}
    end
  end

  defp get_project_id(creds) do
    case ADC.get_project_id(creds) do
      {:ok, project_id} ->
        {:ok, project_id}

      {:error, _} ->
        # Fall back to environment variable
        case System.get_env("VERTEX_PROJECT_ID") do
          nil ->
            {:error, "Project ID required. Set VERTEX_PROJECT_ID environment variable."}
          project_id ->
            {:ok, project_id}
        end
    end
  end
end

# Usage
MyApp.VertexAI.generate("What is machine learning?")
```

### Testing with ADC

```elixir
defmodule MyApp.VertexAITest do
  use ExUnit.Case, async: false

  alias MyApp.VertexAI

  @moduletag :live_api

  setup do
    # Ensure ADC is available for tests
    case Gemini.Auth.ADC.available?() do
      true ->
        :ok
      false ->
        {:skip, "ADC credentials not available"}
    end
  end

  test "generates content using ADC" do
    assert {:ok, response} = VertexAI.generate("Hello!")
    assert is_binary(response)
  end
end
```

## Related Documentation

- [Authentication System](../../AUTHENTICATION_SYSTEM.md)
- [Rate Limiting Guide](rate_limiting.md)
- [Tuning Guide](tunings.md)

## Additional Resources

- [Google Cloud ADC Documentation](https://cloud.google.com/docs/authentication/application-default-credentials)
- [Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-service-accounts)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference/auth/application-default)
