# Use Google Search Suggestions

To use Grounding with Google Search, you must enable Google Search Suggestions, which help users find search results corresponding to a grounded response.

Specifically, you need to display the search queries that are included in the grounded response's metadata. The response includes:

  * `content`: LLM generated response
  * `webSearchQueries`: The queries to be used for Google Search Suggestions

For example, in the following code snippet, Gemini responds to a search-grounded prompt which is asking about a type of tropical plant.

```json
"predictions": [
  {
    "content": "Monstera is a type of vine that thrives in bright indirect light…",
    "groundingMetadata": {
      "webSearchQueries": ["What's a monstera?"],
    }
  }
]
```

You can take this output and display it by using Google Search Suggestions.

## Requirements for Google Search Suggestions

**Do:**

  * Display the Search Suggestion exactly as provided without any modifications while complying with the [Display Requirements](https://www.google.com/search?q=%23display-requirements).
  * Take users directly to the Google Search results page (SRP) when they interact with the Search Suggestion.

**Don't:**

  * Include any interstitial screens or additional steps between the user's tap and the display of the SRP.
  * Display any other search results or suggestions alongside the Search Suggestion or associated grounded LLM response.

## Display requirements

Display the Search Suggestion exactly as provided and don't make any modifications to colors, fonts, or appearance. Ensure the Search Suggestion renders as specified in the following mocks, including for light and dark mode:

(Image mocks are not convertible to simple markdown and are omitted)

Whenever a grounded response is shown, its corresponding Google Search Suggestion should remain visible.

  * **Branding:** You must strictly follow [Google's Guidelines for Third Party Use of Google Brand Features].
  * Google Search Suggestions should be at minimum the full width of the grounded response.

## Behavior on tap

When a user taps the chip, they are taken directly to a Google Search results page (SRP) for the search term displayed in the chip. The SRP can open either within your in-app browser or in a separate browser app. It's important to not minimize, remove, or obstruct the SRP's display in any way. The following animated mockup illustrates the tap-to-SRP interaction.

(Animated mockup is not convertible to simple markdown and is omitted)

## Code to implement a Google Search Suggestion

When you use the API to ground a response to search, the model response provides compliant HTML and CSS styling in the `renderedContent` field which you implement to display Search Suggestions in your application. To see an example of the API response, see the response section in [Grounding with Google Search].

**Note:** The provided HTML and CSS provided in the API response automatically adapts to the user's device settings, displaying in either light or dark mode based on the user's preference indicated by `@media(prefers-color-scheme)`.

## What's next

  * Learn how to [build an interactive chat].
  * Learn how to [use Gemini safely and responsibly].
