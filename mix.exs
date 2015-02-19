defmodule ExrmHeroku.Mixfile do
  use Mix.Project

  def project do
    [app: :exrm_heroku,
     version: "0.1.0",
     elixir: "~> 1.0-dev",
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp description do
    """
    Publish Elixir releases created with exrm release manager to Heroku.
    """
  end

  defp deps do
    [{:exrm, github: "guilleiguaran/exrm", branch: "fix-repackage"}]
  end

  defp package do
    [ files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Guillermo Iguaran"],
      licenses: ["MIT"],
      links: [ { "GitHub", "https://github.com/ride/exrm-heroku" } ] ]
  end
end
