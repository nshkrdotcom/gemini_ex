# Multimodal Test Fixtures

**Purpose:** Minimal test images for live API testing of multimodal content handling
**Created:** 2025-10-07
**Total Size:** ~300 bytes

---

## Test Images

### test_image_1x1.png (67 bytes)
- **Format:** PNG
- **Dimensions:** 1x1 pixel
- **Color:** Transparent
- **Purpose:** Minimal valid PNG for testing auto-detection and processing

### test_image_1x1.jpg (68 bytes)
- **Format:** JPEG
- **Dimensions:** 1x1 pixel
- **Color:** White
- **Purpose:** Minimal valid JPEG for testing format detection

### test_image_2x2_colored.png (79 bytes)
- **Format:** PNG
- **Dimensions:** 2x2 pixels
- **Colors:** Red, Green, Blue, White
- **Purpose:** Color detection and description testing

---

## Usage

### In Live API Tests

```elixir
@fixtures_dir Path.join([__DIR__, "..", "..", "fixtures", "multimodal"])

test "processes real PNG image" do
  image_path = Path.join(@fixtures_dir, "test_image_1x1.png")
  {:ok, image_data} = File.read(image_path)

  content = [
    %{type: "text", text: "What format is this image?"},
    %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
  ]

  {:ok, response} = Gemini.generate(content, model: "gemini-2.5-flash")
end
```

### In Examples

```elixir
# examples/multimodal_demo.exs
image_path = "test/fixtures/multimodal/test_image_1x1.png"
{:ok, image_data} = File.read(image_path)

Gemini.generate([
  %{type: "text", text: "Describe this"},
  %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
])
```

---

## Regenerating Images

If these files are lost or corrupted, regenerate with:

```bash
elixir test/fixtures/multimodal/create_test_images.exs
```

---

## Why Minimal Images?

1. **Small repo size** - Only ~300 bytes total
2. **Fast to load** - No I/O overhead in tests
3. **Deterministic** - Same images every test run
4. **Valid format** - Real PNG/JPEG headers for proper testing
5. **Git-friendly** - Binary but tiny, minimal repo pollution

---

## Image Specifications

### PNG Format
- Magic bytes: `0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A`
- IHDR chunk: Specifies dimensions and color type
- IDAT chunk: Compressed pixel data (zlib)
- IEND chunk: End marker

### JPEG Format
- SOI marker: `0xFF 0xD8`
- APP0 (JFIF): File format info
- SOF0: Frame parameters
- DHT: Huffman tables
- SOS: Scan data
- EOI marker: `0xFF 0xD9`

---

**Maintained By:** gemini_ex test suite
**Do Not Modify:** These are reference test images
**Size:** Intentionally minimal for CI/CD efficiency
