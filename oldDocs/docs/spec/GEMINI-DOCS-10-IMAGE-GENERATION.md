# Image generation

You can generate images using the Gemini API with either Gemini's built-in multimodal capabilities or Imagen, Google's specialized image generation model. For most use cases, start with **Gemini**. Choose **Imagen** for specialized tasks where image quality is critical. See [Choosing the right model](https://www.google.com/search?q=%23choosing-the-right-model) section for more guidance.

All generated images include a [SynthID watermark].

## Before you begin

Ensure you use a supported model and version for image generation:

  * For **Gemini**, use Gemini 2.0 Flash Preview Image Generation.
  * For **Imagen**, use Imagen 3. Note that this model is only available on the **Paid tier**.

You can access both Gemini and Imagen 3 using the same libraries.

**Note:** Image generation may not be available in all regions and countries, review our [Models] page for more information.

## Generate images using Gemini

Gemini can generate and process images conversationally. You can prompt Gemini with text, images, or a combination of both to achieve various image-related tasks, such as image generation and editing.

You must include `responseModalities: ["TEXT", "IMAGE"]` in your configuration. Image-only output is not supported with these models.

### Image generation (text-to-image)

The following code demonstrates how to generate an image based on a descriptive prompt:

(Code examples for Python, JavaScript, Go, and REST are present in the original text and are omitted here for brevity as per instructions)

AI-generated image of a fantastical flying pig

### Image editing (text-and-image-to-image)

To perform image editing, add an image as input. The following example demonstrates uploading base64 encoded images. For multiple images and larger payloads, check the [image input] section.

(Code examples for Python, JavaScript, Go, and REST are present in the original text and are omitted here for brevity as per instructions)

### Other image generation modes

Gemini supports other image interaction modes based on prompt structure and context, including:

  * **Text to image(s) and text (interleaved):** Outputs images with related text.
      * Example prompt: "Generate an illustrated recipe for a paella."
  * **Image(s) and text to image(s) and text (interleaved):** Uses input images and text to create new related images and text.
      * Example prompt: (With an image of a furnished room) "What other color sofas would work in my space? can you update the image?"
  * **Multi-turn image editing (chat):** Keep generating / editing images conversationally.
      * Example prompts: \[upload an image of a blue car.], "Turn this car into a convertible.", "Now change the color to yellow."

### Limitations

  * For best performance, use the following languages: EN, es-MX, ja-JP, zh-CN, hi-IN.
  * Image generation does not support audio or video inputs.
  * Image generation may not always trigger:
      * The model may output text only. Try asking for image outputs explicitly (e.g. "generate an image", "provide images as you go along", "update the image").
      * The model may stop generating partway through. Try again or try a different prompt.
  * When generating text for an image, Gemini works best if you first generate the text and then ask for an image with the text.
  * There are some regions/countries where Image generation is not available. See [Models] for more information.

## Generate images using Imagen 3

This example demonstrates generating images with **Imagen 3**:

(Code examples for Python, JavaScript, Go, and REST are present in the original text and are omitted here for brevity as per instructions)

AI-generated image of a robot holding a red skateboard

### Imagen model parameters

Imagen supports English only prompts at this time and the following parameters:

  * `numberOfImages`: The number of images to generate, from 1 to 4 (inclusive). The default is 4.
  * `aspectRatio`: Changes the aspect ratio of the generated image. Supported values are `"1:1"`, `"3:4"`, `"4:3"`, `"9:16"`, and `"16:9"`. The default is `"1:1"`.
  * `personGeneration`: Allow the model to generate images of people. The following values are supported:
      * `"DONT_ALLOW"`: Block generation of images of people.
      * `"ALLOW_ADULT"`: Generate images of adults, but not children. This is the default.

**Note:** Naming conventions of above parameters vary by programming language.

## Choosing the right model

Choose **Gemini** when:

  * You need contextually relevant images that leverage world knowledge and reasoning.
  * Seamlessly blending text and images is important.
  * You want accurate visuals embedded within long text sequences.
  * You want to edit images conversationally while maintaining context.

Choose **Imagen 3** when:

  * Image quality, photorealism, artistic detail, or specific styles (e.g., impressionism, anime) are top priorities.
  * Performing specialized editing tasks like product background updates or image upscaling.
  * Infusing branding, style, or generating logos and product designs.

## Imagen prompt guide

This section of the Imagen guide shows you how modifying a text-to-image prompt can produce different results, along with examples of images you can create.

### Prompt writing basics

**Note:** Maximum prompt length is 480 tokens.

A good prompt is descriptive and clear, and makes use of meaningful keywords and modifiers. Start by thinking of your **subject**, **context**, and **style**.

  * Image text: A `sketch` (style) of a `modern apartment building` (subject) surrounded by `skyscrapers` (context and background).

  * **Subject:** The first thing to think about with any prompt is the **subject**: the object, person, animal, or scenery you want an image of.

  * **Context and background:** Just as important is the **background or context** in which the subject will be placed. Try placing your subject in a variety of backgrounds. For example, a studio with a white background, outdoors, or indoor environments.

  * **Style:** Finally, add the style of image you want. **Styles** can be general (painting, photograph, sketches) or very specific (pastel painting, charcoal drawing, isometric 3D). You can also combine styles.

After you write a first version of your prompt, refine your prompt by adding more details until you get to the image that you want. Iteration is important. Start by establishing your core idea, and then refine and expand upon that core idea until the generated image is close to your vision.

  * Prompt: A park in the spring next to a lake
  * Prompt: A park in the spring next to a lake, `the sun sets across the lake, golden hour`
  * Prompt: A park in the spring next to a lake, `the sun sets across the lake, golden hour, red wildflowers`

Imagen 3 can transform your ideas into detailed images, whether your prompts are short or long and detailed. Refine your vision through iterative prompting, adding details until you achieve the perfect result.

  * Short prompts let you generate an image quickly.
      * Prompt: close-up photo of a woman in her 20s, street photography, movie still, muted orange warm tones
  * Longer prompts let you add specific details and build your image.
      * Prompt: captivating photo of a woman in her 20s utilizing a street photography style. The image should look like a movie still with muted orange warm tones.

Additional advice for Imagen prompt writing:

  * **Use descriptive language:** Employ detailed adjectives and adverbs to paint a clear picture for Imagen 3.
  * **Provide context:** If necessary, include background information to aid the AI's understanding.
  * **Reference specific artists or styles:** If you have a particular aesthetic in mind, referencing specific artists or art movements can be helpful.
  * **Use prompt engineering tools:** Consider exploring prompt engineering tools or resources to help you refine your prompts and achieve optimal results.
  * **Enhancing the facial details in your personal and group images:** Specify facial details as a focus of the photo (for example, use the word "portrait" in the prompt).

### Generate text in images

Imagen can add text into images, opening up more creative image generation possibilities. Use the following guidance to get the most out of this feature:

  * **Iterate with confidence:** You might have to regenerate images until you achieve the look you want. Imagen's text integration is still evolving, and sometimes multiple attempts yield the best results.
  * **Keep it short:** Limit text to 25 characters or less for optimal generation.
  * **Multiple phrases:** Experiment with two or three distinct phrases to provide additional information. Avoid exceeding three phrases for cleaner compositions.
      * Prompt: A poster with the text "Summerland" in bold font as a title, underneath this text is the slogan "Summer never felt so good"
  * **Guide Placement:** While Imagen can attempt to position text as directed, expect occasional variations. This feature is continually improving.
  * **Inspire font style:** Specify a general font style to subtly influence Imagen's choices. Don't rely on precise font replication, but expect creative interpretations.
  * **Font size:** Specify a font size or a general indication of size (for example, `small`, `medium`, `large`) to influence the font size generation.

### Prompt parameterization

To better control output results, you might find it helpful to parameterize the inputs into Imagen. For example, suppose you want your customers to be able to generate logos for their business, and you want to make sure logos are always generated on a solid color background. You also want to limit the options that the client can select from a menu.

In this example, you can create a parameterized prompt similar to the following:

`A {logo_style} logo for a {company_area} company on a solid color background. Include the text {company_name}.`

In your custom user interface, the customer can input the parameters using a menu, and their chosen value populates the prompt Imagen receives.

For example:

  * Prompt: A `minimalist` logo for a `health care` company on a solid color background. Include the text `Journey`.
  * Prompt: A `modern` logo for a `software` company on a solid color background. Include the text `Silo`.
  * Prompt: A `traditional` logo for a `baking` company on a solid color background. Include the text `Seed`.

## Advanced prompt writing techniques

Use the following examples to create more specific prompts based on attributes like photography descriptors, shapes and materials, historical art movements, and image quality modifiers.

### Photography

Prompt includes: `"A photo of..."`

To use this style, start with using keywords that clearly tell Imagen that you're looking for a photograph. Start your prompts with `"A photo of..."`. For example:

  * Prompt: A photo of `coffee beans in a kitchen on a wooden surface`
  * Prompt: A photo of `a chocolate bar on a kitchen counter`
  * Prompt: A photo of `a modern building with water in the background`

Image source: Each image was generated using its corresponding text prompt with the Imagen 3 model.

### Photography modifiers

In the following examples, you can see several photography-specific modifiers and parameters. You can combine multiple modifiers for more precise control.

  * **Camera Proximity** - `Close up`, `taken from far away`
      * Prompt: A `close-up` photo of coffee beans
      * Prompt: A `zoomed out` photo of a small bag of coffee beans in a messy kitchen
  * **Camera Position** - `aerial`, `from below`
      * Prompt: `aerial photo` of urban city with skyscrapers
      * Prompt: A photo of a forest canopy with blue skies `from below`
  * **Lighting** - `natural`, `dramatic`, `warm`, `cold`
      * Prompt: studio photo of a modern arm chair, `natural lighting`
      * Prompt: studio photo of a modern arm chair, `dramatic lighting`
  * **Camera Settings** - `motion blur`, `soft focus`, `bokeh`, `portrait`
      * Prompt: photo of a city with skyscrapers from the inside of a car with `motion blur`
      * Prompt: `soft focus` photograph of a bridge in an urban city at night
  * **Lens types** - `35mm`, `50mm`, `fisheye`, `wide angle`, `macro`
      * Prompt: photo of a leaf, `macro lens`
      * Prompt: street photography, new york city, `fisheye lens`
  * **Film types** - `black and white`, `polaroid`
      * Prompt: a `polaroid portrait` of a dog wearing sunglasses
      * Prompt: `black and white photo` of a dog wearing sunglasses

Image source: Each image was generated using its corresponding text prompt with the Imagen 3 model.

### Illustration and art

Prompt includes: `"A painting of..."`, `"A sketch of..."`

Art styles vary from monochrome styles like pencil sketches, to hyper-realistic digital art. For example, the following images use the same prompt with different styles:

`"An [art style or creation technique] of an angular sporty electric sedan with skyscrapers in the background"`

  * Prompt: A `technical pencil drawing` of an angular...
  * Prompt: A `charcoal drawing` of an angular...
  * Prompt: A `color pencil drawing` of an angular...
  * Prompt: A `pastel painting` of an angular...
  * Prompt: A `digital art` of an angular...
  * Prompt: An `art deco (poster)` of an angular...

Image source: Each image was generated using its corresponding text prompt with the Imagen 2 model.

### Shapes and materials

Prompt includes: `"...made of..."`, `"...in the shape of..."`

One of the strengths of this technology is that you can create imagery that is otherwise difficult or impossible. For example, you can recreate your company logo in different materials and textures.

  * Prompt: a duffle bag `made of` cheese
  * Prompt: neon tubes `in the shape` of a bird
  * Prompt: an armchair `made of paper, studio photo, origami style`

Image source: Each image was generated using its corresponding text prompt with the Imagen 3 model.

### Historical art references

Prompt includes: `"...in the style of..."`

Certain styles have become iconic over the years. The following are some ideas of historical painting or art styles that you can try.

`"generate an image in the style of [art period or movement] : a wind farm"`

  * Prompt: generate an image `in the style of` an impressionist painting: a wind farm
  * Prompt: generate an image `in the style of` a renaissance painting: a wind farm
  * Prompt: generate an image `in the style of` pop art: a wind farm

Image source: Each image was generated using its corresponding text prompt with the Imagen 3 model.

### Image quality modifiers

Certain keywords can let the model know that you're looking for a high-quality asset. Examples of quality modifiers include the following:

  * **General Modifiers** - `high-quality`, `beautiful`, `stylized`
  * **Photos** - `4K`, `HDR`, `Studio Photo`
  * **Art, Illustration** - `by a professional`, `detailed`

The following are a few examples of prompts without quality modifiers and the same prompt with quality modifiers.

  * Prompt (no quality modifiers): a photo of a corn stalk
  * Prompt (with quality modifiers): `4k HDR beautiful` photo of a corn stalk `taken by a professional photographer`

Image source: Each image was generated using its corresponding text prompt with the Imagen 3 model.

### Aspect ratios

Imagen 3 image generation lets you set five distinct image aspect ratios.

  * **Square** (`1:1`, default) - A standard square photo. Common uses for this aspect ratio include social media posts.
  * **Fullscreen** (`4:3`) - This aspect ratio is commonly used in media or film. It is also the dimensions of most old (non-widescreen) TVs and medium format cameras. It captures more of the scene horizontally (compared to 1:1), making it a preferred aspect ratio for photography.
      * Prompt: close up of a musician's fingers playing the piano, black and white film, vintage (`4:3 aspect ratio`)
      * Prompt: A professional studio photo of french fries for a high end restaurant, in the style of a food magazine (`4:3 aspect ratio`)
  * **Portrait full screen** (`3:4`) - This is the fullscreen aspect ratio rotated 90 degrees. This lets to capture more of the scene vertically compared to the `1:1` aspect ratio.
      * Prompt: a woman hiking, close of her boots reflected in a puddle, large mountains in the background, in the style of an advertisement, dramatic angles (`3:4 aspect ratio`)
      * Prompt: aerial shot of a river flowing up a mystical valley (`3:4 aspect ratio`)
  * **Widescreen** (`16:9`) - This ratio has replaced `4:3` and is now the most common aspect ratio for TVs, monitors, and mobile phone screens (landscape). Use this aspect ratio when you want to capture more of the background (for example, scenic landscapes).
      * Prompt: a man wearing all white clothing sitting on the beach, close up, golden hour lighting (`16:9 aspect ratio`)
  * **Portrait** (`9:16`) - This ratio is widescreen but rotated. This a relatively new aspect ratio that has been popularized by short form video apps (for example, YouTube shorts). Use this for tall objects with strong vertical orientations such as buildings, trees, waterfalls, or other similar objects.
      * Prompt: a digital render of a massive skyscraper, modern, grand, epic with a beautiful sunset in the background (`9:16 aspect ratio`)

### Photorealistic images

Different versions of the image generation model might offer a mix of artistic and photorealistic output. Use the following wording in prompts to generate more photorealistic output, based on the subject you want to generate.

**Note:** Take these keywords as general guidance when you try to create photorealistic images. They aren't required to achieve your goal.

#### Portraits

| Use case         | Lens type   | Focal lengths | Additional details                                          |
| :--------------- | :---------- | :------------ | :---------------------------------------------------------- |
| People (portraits) | Prime, zoom | 24-35mm       | black and white film, Film noir, Depth of field, duotone (mention two colors) |

Using several keywords from the table, Imagen can generate the following portraits:

  * Prompt: A woman, 35mm portrait, blue and grey duotones
      * Model: `imagen-3.0-generate-002`
  * Prompt: A woman, 35mm portrait, film noir
      * Model: `imagen-3.0-generate-002`

#### Objects

| Use case                             | Lens type | Focal lengths | Additional details                  |
| :----------------------------------- | :-------- | :------------ | :---------------------------------- |
| Food, insects, plants (objects, still life) | Macro     | 60-105mm      | High detail, precise focusing, controlled lighting |

Using several keywords from the table, Imagen can generate the following object images:

  * Prompt: leaf of a prayer plant, macro lens, 60mm
      * Model: `imagen-3.0-generate-002`
  * Prompt: a plate of pasta, 100mm Macro lens
      * Model: `imagen-3.0-generate-002`

#### Motion

| Use case             | Lens type       | Focal lengths | Additional details                     |
| :------------------- | :-------------- | :------------ | :------------------------------------- |
| Sports, wildlife (motion) | Telephoto zoom | 100-400mm     | Fast shutter speed, Action or movement tracking |

Using several keywords from the table, Imagen can generate the following motion images:

  * Prompt: a winning touchdown, fast shutter speed, movement tracking
      * Model: `imagen-3.0-generate-002`
  * Prompt: A deer running in the forest, fast shutter speed, movement tracking
      * Model: `imagen-3.0-generate-002`
