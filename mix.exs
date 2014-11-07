defmodule Graphitex.Mixfile do
  use Mix.Project

  @description "Carbon wrapper for Elixir."

  def project do
    [
        app: :graphitex,
        version: "0.0.1",
        elixir: "~> 1.0",
        deps: deps,
        package: package,
        description: @description,
        source_url: "https://github.com/tappsi/graphitex"
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    []
  end

  defp package do
    [
        contributors: ["Ricardo Lanziano", "Óscar López", "Maicol Garces"],
        licenses: ["FreeBSD License"],
        links: %{"GitHub" => "https://github.com/tappsi/graphitex"}
    ]
  end
end
