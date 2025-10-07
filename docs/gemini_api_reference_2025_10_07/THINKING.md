Source: https://ai.google.dev/gemini-api/docs/thinking
Fetched: 2025-10-07

# Gemini thinking

A new native audio model is available for the Live API.[Learn more](https://ai.google.dev/gemini-api/docs/live)
- [Home](https://ai.google.dev/)
- [Gemini API](https://ai.google.dev/gemini-api)
- [Gemini API docs](https://ai.google.dev/gemini-api/docs)

# Gemini thinking

The[Gemini 2.5 series models](/gemini-api/docs/models)use an internal
"thinking process" that significantly improves their reasoning and multi-step
planning abilities, making them highly effective for complex tasks such as
coding, advanced mathematics, and data analysis.

This guide shows you how to work with Gemini's thinking capabilities using the
Gemini API.

## Before you begin

Ensure you use a supported 2.5 series model for thinking.
You might find it beneficial to explore these models in AI Studio
before diving into the API:
- [Try Gemini 2.5 Flash in AI Studio](https://aistudio.google.com/prompts/new_chat?model=gemini-2.5-flash)
- [Try Gemini 2.5 Pro in AI Studio](https://aistudio.google.com/prompts/new_chat?model=gemini-2.5-pro)
- [Try Gemini 2.5 Flash-Lite in AI Studio](https://aistudio.google.com/prompts/new_chat?model=gemini-2.5-flash-lite)

## Generating content with thinking

Initiating a request with a thinking model is similar to any other content
generation request. The key difference lies in specifying one of the[models with thinking support](#supported-models)in the`model`field, as
demonstrated in the following[text generation](/gemini-api/docs/text-generation#text-input)example:

### Python

```

from google import genai

client = genai.Client()
prompt = "Explain the concept of Occam's Razor and provide a simple, everyday example."
response = client.models.generate_content(
    model="gemini-2.5-pro",
    contents=prompt
)

print(response.text)

```

### JavaScript

```

import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({});

async function main() {
  const prompt = "Explain the concept of Occam's Razor and provide a simple, everyday example.";

  const response = await ai.models.generateContent({
    model: "gemini-2.5-pro",
    contents: prompt,
  });

  console.log(response.text);
}

main();

```

### Go

```

package main

import (
  "context"
  "fmt"
  "log"
  "os"
  "google.golang.org/genai"
)

func main() {
  ctx := context.Background()
  client, err := genai.NewClient(ctx, nil)
  if err != nil {
      log.Fatal(err)
  }

  prompt := "Explain the concept of Occam's Razor and provide a simple, everyday example."
  model := "gemini-2.5-pro"

  resp, _ := client.Models.GenerateContent(ctx, model, genai.Text(prompt), nil)

  fmt.Println(resp.Text())
}

```

### REST

```

curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent" \
 -H "x-goog-api-key: $GEMINI_API_KEY" \
 -H 'Content-Type: application/json' \
 -X POST \
 -d '{
   "contents": [
     {
       "parts": [
         {
           "text": "Explain the concept of Occam\'s Razor and provide a simple, everyday example."
         }
       ]
     }
   ]
 }'
 ```

```

## Thinking budgets

The`thinkingBudget`parameter guides the model on the number of
thinking tokens to use when generating a response. A higher token count
generally allows for more detailed reasoning, which can be beneficial for
tackling more[complex tasks](#tasks). If latency is more important, use a lower
budget or disable thinking by setting`thinkingBudget`to 0.
Setting the`thinkingBudget`to -1 turns
on**dynamic thinking**, meaning the model will adjust the budget based on the
complexity of the request.

The`thinkingBudget`is only[supported](#supported-models)in Gemini
2.5 Flash, 2.5 Pro, and 2.5 Flash-Lite. Depending on the prompt, the model might
overflow or underflow the token budget.

The following are`thinkingBudget`configuration details for each model type.

| Model | Default setting(Thinking budget is not set) | Range | Disable thinking | Turn on dynamic thinking |
| --- | --- | --- | --- | --- |
| 2.5 Pro | Dynamic thinking: Model decides when and how much to think | 128 to 32768 | N/A: Cannot disable thinking | thinkingBudget = -1 |
| 2.5 Flash | Dynamic thinking: Model decides when and how much to think | 0 to 24576 | thinkingBudget = 0 | thinkingBudget = -1 |
| 2.5 Flash Preview | Dynamic thinking: Model decides when and how much to think | 0 to 24576 | thinkingBudget = 0 | thinkingBudget = -1 |
| 2.5 Flash Lite | Model does not think | 512 to 24576 | thinkingBudget = 0 | thinkingBudget = -1 |
| 2.5 Flash Lite Preview | Model does not think | 512 to 24576 | thinkingBudget = 0 | thinkingBudget = -1 |
| Robotics-ER 1.5 Preview | Dynamic thinking: Model decides when and how much to think | 0 to 24576 | thinkingBudget = 0 | thinkingBudget = -1 |
| 2.5 Flash Live Native Audio Preview (09-2025) | Dynamic thinking: Model decides when and how much to think | 0 to 24576 | thinkingBudget = 0 | thinkingBudget = -1 |

### Python

```

from google import genai
from google.genai import types

client = genai.Client()

response = client.models.generate_content(
    model="gemini-2.5-pro",
    contents="Provide a list of 3 famous physicists and their key contributions",
    config=types.GenerateContentConfig(
        thinking_config=types.ThinkingConfig(thinking_budget=1024)
        # Turn off thinking:
        # thinking_config=types.ThinkingConfig(thinking_budget=0)
        # Turn on dynamic thinking:
        # thinking_config=types.ThinkingConfig(thinking_budget=-1)
    ),
)

print(response.text)

```

### JavaScript

```

import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({});

async function main() {
  const response = await ai.models.generateContent({
    model: "gemini-2.5-pro",
    contents: "Provide a list of 3 famous physicists and their key contributions",
    config: {
      thinkingConfig: {
        thinkingBudget: 1024,
        // Turn off thinking:
        // thinkingBudget: 0
        // Turn on dynamic thinking:
        // thinkingBudget: -1
      },
    },
  });

  console.log(response.text);
}

main();

```

### Go

```

package main

import (
  "context"
  "fmt"
  "google.golang.org/genai"
  "os"
)

func main() {
  ctx := context.Background()
  client, err := genai.NewClient(ctx, nil)
  if err != nil {
      log.Fatal(err)
  }

  thinkingBudgetVal := int32(1024)

  contents := genai.Text("Provide a list of 3 famous physicists and their key contributions")
  model := "gemini-2.5-pro"
  resp, _ := client.Models.GenerateContent(ctx, model, contents, &genai.GenerateContentConfig{
    ThinkingConfig: &genai.ThinkingConfig{
      ThinkingBudget: &thinkingBudgetVal,
      // Turn off thinking:
      // ThinkingBudget: int32(0),
      // Turn on dynamic thinking:
      // ThinkingBudget: int32(-1),
    },
  })

fmt.Println(resp.Text())
}

```

### REST

```

curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent" \
-H "x-goog-api-key: $GEMINI_API_KEY" \
-H 'Content-Type: application/json' \
-X POST \
-d '{
  "contents": [
    {
      "parts": [
        {
          "text": "Provide a list of 3 famous physicists and their key contributions"
        }
      ]
    }
  ],
  "generationConfig": {
    "thinkingConfig": {
          "thinkingBudget": 1024
    }
  }
}'

```

## Thought summaries

Thought summaries are synthesized versions of the model's raw thoughts and offer
insights into the model's internal reasoning process. Note that
thinking budgets apply to the model's raw thoughts and not to thought
summaries.

You can enable thought summaries by setting`includeThoughts`to`true`in your
request configuration. You can then access the summary by iterating through the`response`parameter's`parts`, and checking the`thought`boolean.

Here's an example demonstrating how to enable and retrieve thought summaries
without streaming, which returns a single, final thought summary with the
response:

### Python

```

from google import genai
from google.genai import types

client = genai.Client()
prompt = "What is the sum of the first 50 prime numbers?"
response = client.models.generate_content(
  model="gemini-2.5-pro",
  contents=prompt,
  config=types.GenerateContentConfig(
    thinking_config=types.ThinkingConfig(
      include_thoughts=True
    )
  )
)

for part in response.candidates[0].content.parts:
  if not part.text:
    continue
  if part.thought:
    print("Thought summary:")
    print(part.text)
    print()
  else:
    print("Answer:")
    print(part.text)
    print()

```

### JavaScript

```

import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({});

async function main() {
  const response = await ai.models.generateContent({
    model: "gemini-2.5-pro",
    contents: "What is the sum of the first 50 prime numbers?",
    config: {
      thinkingConfig: {
        includeThoughts: true,
      },
    },
  });

  for (const part of response.candidates[0].content.parts) {
    if (!part.text) {
      continue;
    }
    else if (part.thought) {
      console.log("Thoughts summary:");
      console.log(part.text);
    }
    else {
      console.log("Answer:");
      console.log(part.text);
    }
  }
}

main();

```

### Go

```

package main

import (
  "context"
  "fmt"
  "google.golang.org/genai"
  "os"
)

func main() {
  ctx := context.Background()
  client, err := genai.NewClient(ctx, nil)
  if err != nil {
      log.Fatal(err)
  }

  contents := genai.Text("What is the sum of the first 50 prime numbers?")
  model := "gemini-2.5-pro"
  resp, _ := client.Models.GenerateContent(ctx, model, contents, &genai.GenerateContentConfig{
    ThinkingConfig: &genai.ThinkingConfig{
      IncludeThoughts: true,
    },
  })

  for _, part := range resp.Candidates[0].Content.Parts {
    if part.Text != "" {
      if part.Thought {
        fmt.Println("Thoughts Summary:")
        fmt.Println(part.Text)
      } else {
        fmt.Println("Answer:")
        fmt.Println(part.Text)
      }
    }
  }
}

```


And here is an example using thinking with streaming, which returns rolling,
incremental summaries during generation:

### Python

```

from google import genai
from google.genai import types

client = genai.Client()

prompt = """
Alice, Bob, and Carol each live in a different house on the same street: red, green, and blue.
The person who lives in the red house owns a cat.
Bob does not live in the green house.
Carol owns a dog.
The green house is to the left of the red house.
Alice does not own a cat.
Who lives in each house, and what pet do they own?
"""

thoughts = ""
answer = ""

for chunk in client.models.generate_content_stream(
    model="gemini-2.5-pro",
    contents=prompt,
    config=types.GenerateContentConfig(
      thinking_config=types.ThinkingConfig(
        include_thoughts=True
      )
    )
):
  for part in chunk.candidates[0].content.parts:
    if not part.text:
      continue
    elif part.thought:
      if not thoughts:
        print("Thoughts summary:")
      print(part.text)
      thoughts += part.text
    else:
      if not answer:
        print("Answer:")
      print(part.text)
      answer += part.text

```

### JavaScript

```

import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({});

const prompt = `Alice, Bob, and Carol each live in a different house on the same
street: red, green, and blue. The person who lives in the red house owns a cat.
Bob does not live in the green house. Carol owns a dog. The green house is to
the left of the red house. Alice does not own a cat. Who lives in each house,
and what pet do they own?`;

let thoughts = "";
let answer = "";

async function main() {
  const response = await ai.models.generateContentStream({
    model: "gemini-2.5-pro",
    contents: prompt,
    config: {
      thinkingConfig: {
        includeThoughts: true,
      },
    },
  });

  for await (const chunk of response) {
    for (const part of chunk.candidates[0].content.parts) {
      if (!part.text) {
        continue;
      } else if (part.thought) {
        if (!thoughts) {
          console.log("Thoughts summary:");
        }
        console.log(part.text);
        thoughts = thoughts + part.text;
      } else {
        if (!answer) {
          console.log("Answer:");
        }
        console.log(part.text);
        answer = answer + part.text;
      }
    }
  }
}

await main();

```

### Go

```

package main

import (
  "context"
  "fmt"
  "log"
  "os"
  "google.golang.org/genai"
)

const prompt = `
Alice, Bob, and Carol each live in a different house on the same street: red, green, and blue.
The person who lives in the red house owns a cat.
Bob does not live in the green house.
Carol owns a dog.
The green house is to the left of the red house.
Alice does not own a cat.
Who lives in each house, and what pet do they own?
`

func main() {
  ctx := context.Background()
  client, err := genai.NewClient(ctx, nil)
  if err != nil {
      log.Fatal(err)
  }

  contents := genai.Text(prompt)
  model := "gemini-2.5-pro"

  resp := client.Models.GenerateContentStream(ctx, model, contents, &genai.GenerateContentConfig{
    ThinkingConfig: &genai.ThinkingConfig{
      IncludeThoughts: true,
    },
  })

  for chunk := range resp {
    for _, part := range chunk.Candidates[0].Content.Parts {
      if len(part.Text) == 0 {
        continue
      }

      if part.Thought {
        fmt.Printf("Thought: %s\n", part.Text)
      } else {
        fmt.Printf("Answer: %s\n", part.Text)
      }
    }
  }
}

```

## Thought signatures

Because standard Gemini API text and content generation calls are stateless,
when using thinking in multi-turn interactions (such as chat), the model doesn't
have access to thought context from previous turns.

You can maintain thought context using thought signatures, which are encrypted
representations of the model's internal thought process. The model returns
thought signatures in the response object when thinking and[function calling](/gemini-api/docs/function-calling#thinking)are enabled. To ensure the model maintains context across multiple turns of a
conversation, you must provide the thought signatures back to the model in the
subsequent requests.

You will receive thought signatures when:
- Thinking is enabled and thoughts are generated.
- The request includes[function declarations](/gemini-api/docs/function-calling#step-2).
**Note:**Thought signatures are only available when you're using function calling,
specifically, your request must include[function declarations](/gemini-api/docs/function-calling#step-2).
You can find an example of thinking with function calls on the[Function calling](/gemini-api/docs/function-calling#thinking)page.

Other usage limitations to consider with function calling include:
- Signatures are returned from the model within other parts in the response,
for example function calling or text parts. Return the
entire response with all parts back to the model in subsequent turns.
- Don't concatenate parts with signatures together.
- Don't merge one part with a signature with another part without a signature.

## Pricing
**Note:****Summaries**are available in the[free and paid tiers](/gemini-api/docs/pricing)of the API.**Thought signatures**will increase the
input tokens you are charged when sent back as part of the request.
When thinking is turned on, response pricing is the sum of output
tokens and thinking tokens. You can get the total number of generated thinking
tokens from the`thoughtsTokenCount`field.

### Python

```

# ...
print("Thoughts tokens:",response.usage_metadata.thoughts_token_count)
print("Output tokens:",response.usage_metadata.candidates_token_count)

```

### JavaScript

```

// ...
console.log(`Thoughts tokens: ${response.usageMetadata.thoughtsTokenCount}`);
console.log(`Output tokens: ${response.usageMetadata.candidatesTokenCount}`);

```

### Go

```

// ...
usageMetadata, err := json.MarshalIndent(response.UsageMetadata, "", "  ")
if err != nil {
  log.Fatal(err)
}
fmt.Println("Thoughts tokens:", string(usageMetadata.thoughts_token_count))
fmt.Println("Output tokens:", string(usageMetadata.candidates_token_count))

```

Thinking models generate full thoughts to improve the quality of the final
response, and then output[summaries](#summaries)to provide insight into the
thought process. So, pricing is based on the full thought tokens the
model needs to generate to create a summary, despite only the summary being
output from the API.

You can learn more about tokens in the[Token counting](/gemini-api/docs/tokens)guide.

## Supported models

Thinking features are supported on all the 2.5 series models.
You can find all model capabilities on the[model overview](/gemini-api/docs/models)page.

## Best practices

This section includes some guidance for using thinking models efficiently.
As always, following our[prompting guidance and best practices](/gemini-api/docs/prompting-strategies)will get you the best results.

### Debugging and steering
- **Review reasoning**: When you're not getting your expected response from the
thinking models, it can help to carefully analyze Gemini's thought summaries.
You can see how it broke down the task and arrived at its conclusion, and use
that information to correct towards the right results.
- **Provide Guidance in Reasoning**: If you're hoping for a particularly lengthy
output, you may want to provide guidance in your prompt to constrain the[amount of thinking](#set-budget)the model uses. This lets you reserve more
of the token output for your response.

### Task complexity
- **Easy Tasks (Thinking could be OFF):**For straightforward requests where
complex reasoning isn't required, such as fact retrieval or
classification, thinking is not required. Examples include:
- "Where was DeepMind founded?"
- "Is this email asking for a meeting or just providing information?"
- **Medium Tasks (Default/Some Thinking):**Many common requests benefit from a
degree of step-by-step processing or deeper understanding. Gemini can flexibly
use thinking capability for tasks like:
- Analogize photosynthesis and growing up.
- Compare and contrast electric cars and hybrid cars.
- **Hard Tasks (Maximum Thinking Capability):**For truly complex challenges,
such as solving complex math problems or coding tasks, we recommend setting
a high thinking budget. These types of tasks require the model to engage
its full reasoning and planning capabilities, often
involving many internal steps before providing an answer. Examples include:
- Solve problem 1 in AIME 2025: Find the sum of all integer bases b > 9 for
which 17bis a divisor of 97b.
- Write Python code for a web application that visualizes real-time stock
market data, including user authentication. Make it as efficient as
possible.

## Thinking with tools and capabilities

Thinking models work with all of Gemini's tools and capabilities. This allows
the models to interact with external systems, execute code,
or access real-time information, incorporating the results into their reasoning
and final response.
- The[search tool](/gemini-api/docs/grounding)allows the model to query
Google Search to find up-to-date information or information beyond
its training data. This is useful for questions about recent events or
highly specific topics.
- The[code execution tool](/gemini-api/docs/code-execution)enables the model
to generate and run Python code to perform calculations, manipulate data,
or solve problems that are best handled algorithmically. The model receives
the code's output and can use it in its response.
- With[structured output](/gemini-api/docs/structured-output), you can
constrain Gemini to respond with JSON. This is particularly useful for
integrating the model's output into applications.
- [Function calling](/gemini-api/docs/function-calling)connects the thinking
model to external tools and APIs, so it can reason about when to call the right
function and what parameters to provide.
- [URL Context](/gemini-api/docs/url-context)provides the model with URLs as
additional context for your prompt. The model can then retrieve content from
the URLs and use that content to inform and shape its response.

You can try examples of using tools with thinking models in the[Thinking cookbook](https://colab.sandbox.google.com/github/google-gemini/cookbook/blob/main/quickstarts/Get_started_thinking.ipynb).

## What's next?
- To work through more in depth examples, like:
- Using tools with thinking
- Streaming with thinking
- Adjusting the thinking budget for different results

and more, try our[Thinking cookbook](https://colab.sandbox.google.com/github/google-gemini/cookbook/blob/main/quickstarts/Get_started_thinking.ipynb).
- Thinking coverage is now available in our[OpenAI Compatibility](/gemini-api/docs/openai#thinking)guide.
- For more info about Gemini 2.5 Pro, Gemini Flash 2.5, and Gemini 2.5
Flash-Lite, visit the[model page](/gemini-api/docs/models).