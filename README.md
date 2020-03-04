
Library to parse out exif tags and thumbnail data from jpeg/tiff images.

## Installation

If [available in Hex](https://hex.pm/packages/elixir_exif), the package can be installed as:

  1. Add elixir_exif to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [{:elixir_exif, "~> 0.1.0"}]
  end
```

## Usage

```elixir
  {:ok, fields, thumbnail} = ElixirExif.parse_file("path/to/image.jpg")

  {:ok, fields, thumbnail} = ElixirExif.parse_binary(<<image binary>>)
```
