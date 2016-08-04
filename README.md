
Library to parse out exif tags and thumbnail data from jpeg/tiff images.

The only other existing exif parser I found for Elixir ([ExExif](https://github.com/pragdave/exexif)) is currently dead and non-functional as of time of writing, so I wrote this based on it.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add elixir_exif to your list of dependencies in `mix.exs`:

        def deps do
          [{:elixir_exif, "~> 0.1.0"}]
        end

## Usage

        {:ok, fields, thumbnail} = ElixirExif.parse_file("path/to/image.jpg")

        {:ok, fields, thumbnail} = ElixirExif.parse_binary(<<image binary>>)
