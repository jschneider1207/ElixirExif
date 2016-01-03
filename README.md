
Library to parse out exif tags and thumbnail data from jpeg/tiff images.  
The only other existing exif parser I found for Elixir is [ExExif](https://github.com/pragdave/exexif)
which is currently dead as of time of writing, so I wrote this based on it.

## Usage

        {:ok, fields, thumbnail} = ElixirExif.parse_file("path/to/image.jpg")

        {:ok, fields, thumbnail} = ElixirExif.parse_binary(<<image binary>>)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add elixir_exif to your list of dependencies in `mix.exs`:

        def deps do
          [{:elixir_exif, "~> 0.0.1"}]
        end

  2. Ensure elixir_exif is started before your application:

        def application do
          [applications: [:elixir_exif]]
        end
