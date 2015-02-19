defmodule ExrmHerokuTest do
  use ExUnit.Case
  alias ReleaseManager.Config
  alias ReleaseManager.Utils
  import ReleaseManager.Utils
  alias ReleaseManager.Plugin.Heroku

  setup do
    config = %Config{name: "test", version: "0.0.1"}
    {:ok, config: Map.merge(config, %{heroku_app: "test", slug_command: "echo"})}
  end

  test "creates the Procfile", meta do
    Heroku.before_release(meta[:config])

    assert File.exists?(rel_file_dest_path("Procfile"))

    File.rm_rf!(rel_dest_path)
  end

  test "executes slug command passing the created tar as argument", meta do
    config = meta[:config]
    app_path = rel_dest_path([config.name])
    File.mkdir_p!(app_path)
    tarball = Path.join([Path.expand("fixtures", __DIR__), "test.tar.gz"])
    File.cp!(tarball, Path.join([app_path, "test-0.0.1.tar.gz"]))

    command = Heroku.after_release(config)

    assert Regex.match?(~r/-dir [\w\/]+ -app test -release/, command)

    File.rm_rf!(rel_dest_path)
  end
end
