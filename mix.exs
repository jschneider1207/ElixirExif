defmodule ElixirExif.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_exif,
     version: "0.2.0",
     elixir: "~> 1.4",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.14.5", only: :dev}]
  end

  defp description do
    """
    Parse exif and thumbnail data from jpeg/tiff images.
    """
  end

  defp package do
    [files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     maintainers: ["Sam Schneider"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/sschneider1207/ElixirExif"}]
  end
end
