#!/usr/bin/env elixir

# Script to create minimal test images for multimodal testing
# Run with: elixir test/fixtures/multimodal/create_test_images.exs

defmodule CreateTestImages do
  def run do
    IO.puts("Creating minimal test images for multimodal testing...")

    create_1x1_png()
    create_1x1_jpeg()
    create_2x2_colored_png()

    IO.puts("✅ Test images created successfully!")
    IO.puts("\nTotal size:")
    System.cmd("du", ["-sh", "test/fixtures/multimodal"], into: IO.stream(:stdio, :line))
  end

  defp create_1x1_png do
    # Minimal valid PNG: 1x1 transparent pixel (67 bytes)
    png_data = <<
      # PNG signature
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      # IHDR chunk
      # Length
      0x00,
      0x00,
      0x00,
      0x0D,
      # "IHDR"
      0x49,
      0x48,
      0x44,
      0x52,
      # Width: 1
      0x00,
      0x00,
      0x00,
      0x01,
      # Height: 1
      0x00,
      0x00,
      0x00,
      0x01,
      # 8-bit RGBA
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      # CRC
      0x1F,
      0x15,
      0xC4,
      0x89,
      # IDAT chunk (compressed pixel data)
      # Length
      0x00,
      0x00,
      0x00,
      0x0A,
      # "IDAT"
      0x49,
      0x44,
      0x41,
      0x54,
      0x08,
      0xD7,
      0x63,
      0x60,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x01,
      # CRC
      0xE2,
      0x21,
      0xBC,
      0x33,
      # IEND chunk
      # Length
      0x00,
      0x00,
      0x00,
      0x00,
      # "IEND"
      0x49,
      0x45,
      0x4E,
      0x44,
      # CRC
      0xAE,
      0x42,
      0x60,
      0x82
    >>

    File.write!("test/fixtures/multimodal/test_image_1x1.png", png_data)
    IO.puts("  ✓ Created test_image_1x1.png (#{byte_size(png_data)} bytes)")
  end

  defp create_1x1_jpeg do
    # Minimal valid JPEG: 1x1 white pixel
    jpeg_data = <<
      # SOI (Start of Image)
      0xFF,
      0xD8,
      # APP0 (JFIF header)
      0xFF,
      0xE0,
      0x00,
      0x10,
      # "JFIF\0"
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      # Version 1.1
      0x01,
      0x01,
      # No units
      0x00,
      # X/Y density = 1
      0x00,
      0x01,
      0x00,
      0x01,
      # No thumbnail
      0x00,
      0x00,
      # SOF0 (Start of Frame - Baseline DCT)
      0xFF,
      0xC0,
      0x00,
      0x0B,
      # 8-bit precision
      0x08,
      # Height=1, Width=1
      0x00,
      0x01,
      0x00,
      0x01,
      # 1 component
      0x01,
      # Component info
      0x01,
      0x11,
      0x00,
      # DHT (Define Huffman Table) - minimal
      0xFF,
      0xC4,
      0x00,
      0x14,
      # Table 0, DC
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      # SOS (Start of Scan)
      0xFF,
      0xDA,
      0x00,
      0x08,
      # 1 component
      0x01,
      0x01,
      0x00,
      0x00,
      0x3F,
      0x00,
      # Minimal scan data
      0xF8,
      # EOI (End of Image)
      0xFF,
      0xD9
    >>

    File.write!("test/fixtures/multimodal/test_image_1x1.jpg", jpeg_data)
    IO.puts("  ✓ Created test_image_1x1.jpg (#{byte_size(jpeg_data)} bytes)")
  end

  defp create_2x2_colored_png do
    # 2x2 PNG with red, green, blue, white pixels (for color detection tests)
    png_data = <<
      # PNG signature
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      # IHDR chunk (2x2 image)
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      # Width: 2
      0x00,
      0x00,
      0x00,
      0x02,
      # Height: 2
      0x00,
      0x00,
      0x00,
      0x02,
      # 8-bit RGB
      0x08,
      0x02,
      0x00,
      0x00,
      0x00,
      # CRC
      0x25,
      0xE5,
      0x88,
      0x57,
      # IDAT chunk (compressed RGB data)
      0x00,
      0x00,
      0x00,
      0x16,
      0x49,
      0x44,
      0x41,
      0x54,
      0x08,
      0xD7,
      0x63,
      0xF8,
      0xCF,
      0xC0,
      0xC0,
      0xC0,
      0xF0,
      0x9F,
      0x81,
      0x81,
      0x01,
      0x62,
      0x0C,
      0x0C,
      0x0C,
      0x00,
      0x23,
      0xC7,
      0x02,
      0x1E,
      # CRC
      0xF3,
      0x4E,
      0xB4,
      0x7A,
      # IEND chunk
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82
    >>

    File.write!("test/fixtures/multimodal/test_image_2x2_colored.png", png_data)
    IO.puts("  ✓ Created test_image_2x2_colored.png (#{byte_size(png_data)} bytes)")
  end
end

CreateTestImages.run()
