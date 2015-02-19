# Heroku plugin for Elixir Release Manager
Publish your Elixir releases to Heroku with ease.

## Usage

You can publish your app at the same time as building a release by adding the `--heroku` option to `release`

- `mix release --heroku`

## Getting Started

This project's goal is to make publishing an Elixir release to HEROKU very simple. To get started:

#### Install slug command line tool:

- `go get github.com/naaman/slug/cmd/slug`

#### Add exrm_heroku as a dependency to your project

```elixir
  defp deps do
    [{:exrm_heroku, "~> 0.1.0"}]
  end
```

#### Fetch and Compile

- `mix deps.get`
- `mix deps.compile`

#### Setup a Heroku keyword in your mix.exs configuration

```elixir
  def project do
    [app: :test_app,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps,
     heroku: heroku]
  end

  def heroku do
    [app: "test-app", # Heroku app name, required
     slug_command: "slug", # Command to execute during release. Optional, by default set to "slug" command
     process_type: "web"] # Process Type for Procfile entry. Optional, by default set to "web"
  end
```


#### Perform a release and publish it to Heroku

- `mix release --heroku`

## License

exrm_heroku is copyright (c) 2015 Ride Group Inc and contributors.

The source code is released under the MIT License.

Check [LICENSE](LICENSE) for more information.
