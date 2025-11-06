# Improving Structured Outputs in the Gemini API

**Nov 05, 2025** · 2 min read

**G**
**Gemini API Team**

**Share**

-----

Today, we're announcing enhancements to Structured Outputs in the Gemini API, with expanded support for JSON Schema and better adherence to property ordering in the output.

Structured Outputs enable AI models to generate responses that guarantee adherence to a specific schema, which is important for tasks like data extraction and database population. They are also important for agent communication: one agent’s output becomes another’s formatted input, enabling complex multi-agent systems to collaborate without translation layers.

## Expanded JSON Schema support

We’ve now added support for JSON Schema to all actively supported Gemini models. This enables libraries like Pydantic (Python) or Zod (JavaScript/TypeScript) to work out-of-the-box with the Gemini API. It builds upon the current support for the Gemini API’s Schema object that is based on OpenAPI 3.0 for Structured Outputs and Function Calling.

This update also adds support for frequently requested JSON Schema keywords, including:

  * `anyOf` for conditional structures (Unions)
  * `$ref` for recursive schemas
  * `minimum` and `maximum` for numeric constraints
  * `additionalProperties` and `type: 'null'`
  * `prefixItems` for tuple-like arrays

## Implicit property ordering

One of the important updates we have made is that the API now preserves the same order as the ordering of keys in the schema. This is supported for all Gemini 2.5 models and beyond and also applies to our OpenAI compatibility API. You can see this in action in this content moderation example using Pydantic:

```python
from google import genai
from pydantic import BaseModel, Field
from typing import Union, Literal

class SpamDetails(BaseModel):
    """Details for content classified as spam."""
    reason: str = Field(description="The reason why the content is considered spam.")
    spam_type: Literal["phishing", "scam", "unsolicited promotion", "other"] = Field(description="The type of spam.")

class NotSpamDetails(BaseModel):
    """Details for content classified as not spam."""
    summary: str = Field(description="A brief summary of the content.")
    is_safe: bool = Field(description="Whether the content is safe for all audiences.")

class ModerationResult(BaseModel):
    """The result of content moderation."""
    decision: Union[SpamDetails, NotSpamDetails]

client = genai.Client()

prompt = """
Please moderate the following content and provide a decision.
Content: 'Congratulations! You've won a free cruise to the Bahamas. Click here to claim your prize: www.definitely-not-a-scam.com'
"""

response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=prompt,
    config={
        "response_mime_type": "application/json",
        "response_json_schema": ModerationResult.model_json_schema(),
    },
)

recipe = ModerationResult.model_validate_json(response.text)
print(recipe)
```

## Structured Outputs in the real world

Structured Outputs is one of the most frequently used tools by developers building real-world AI applications. Here are some examples of how some of our early access partners have used the tool to improve their workflows:

For **Agentic Users**, a platform for autonomous agents for the web, the most significant impact and cost savings from using Structured Outputs has been in data extraction. They rely on Pydantic + `responseJsonSchema` for use cases like extracting attributes related to brand guidelines from image and text examples provided by our users, and `parametersJsonSchema` for all function declarations.

> “We are building AI agents for the agentic web, and our main goal is to build trust in AI agents for handling business operations. Being able to define precise schemas and trust the output is key to our production systems. Structured Outputs have reduced API calls by up to 6x in some workflows and completely eliminated the broken JSON responses that used to require extra validation checks.”
>
> **L**
> **Luis Vega**
> Founder and CEO at Agentic Users

**Alkimi AI** creates AI assistants for businesses and education institutions grounded in their knowledge. Using JSON Schema they are able to reliably pass data through a guaranteed schema within their multi-stage LLM pipeline. This helps them efficiently automate the configuration of their AI assistants — “Agent Wizard” — for each of their partners.

> “For us, Structured Outputs are all about reliability, speed and cost efficiency. By forcing the LLM to provide a predictable, machine-readable format, we can build more robust features faster, reduce errors, and use cheaper models for tasks that would otherwise require more expensive ones.”
>
> **D**
> **Dillon Uzar**
> Founder of Alkimi AI

These updates are available in the API today so head over to our documentation to learn more.

-----

