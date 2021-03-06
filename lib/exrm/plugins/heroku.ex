defmodule ReleaseManager.Plugin.Heroku do
  @name "protocol.consolidation"
  @shortdoc "Performs protocol consolidation for your release."

  use    ReleaseManager.Plugin
  alias  ReleaseManager.Config
  alias  ReleaseManager.Utils
  import ReleaseManager.Utils

  @_NAME          "{{{PROJECT_NAME}}}"
  @_PROCESS_TYPE  "{{{PROCESS_TYPE}}}"

  def before_release(%{heroku: true} = config) do
    config
    |> do_before_release_config
    |> do_copy_procfile
  end

  def before_release(_), do: nil

  def after_release(%{heroku: true} = config) do
    config = config |> do_after_release_config
    slug_path = config |> do_unpack_release
    config |> do_release_slug(slug_path)
  end

  def after_release(_), do: nil

  def after_cleanup(_), do: nil

  def do_before_release_config(config) do
    process_type = config |> get_config_item(:process_type, "web")

    config |> Map.merge(%{process_type: process_type})
  end

  def do_after_release_config(config) do
    heroku_app = config |> get_config_item(:app, config.name)
    slug_command = config |> get_config_item(:slug_command, "slug")

    config |> Map.merge(%{heroku_app: heroku_app, slug_command: slug_command})
  end

  defp do_copy_procfile(config) do
    procfile_path = Path.join([File.cwd!, "Procfile"])
    unless File.exists?(procfile_path) do
      procfile_path = do_generate_procfile(config)
    end

    # Check if relx.config exist
    relx_conf_path = rel_file_dest_path("relx.config")
    unless File.exists?(relx_conf_path) do
      File.touch(relx_conf_path)
    end

    # Load relx.config
    relx_config = relx_conf_path |> Utils.read_terms

    # Add overlay to relx.config which copies Procfile to release
    overlays = [overlay: [
      {:copy, '#{procfile_path}', 'Procfile'}
    ]]

    updated = Utils.merge(relx_config, overlays)
    # Persist relx.config
    Utils.write_terms(relx_conf_path, updated)

    config
  end

  defp do_generate_procfile(config) do
    debug "Generating Procfile..."
    procfile_template = template_path("Procfile")
    procfile_path = rel_file_dest_path("Procfile")

    contents = File.read!(procfile_template)
    |> String.replace(@_NAME, config.name)
    |> String.replace(@_PROCESS_TYPE, config.process_type || "web")

    File.mkdir_p(rel_file_dest_path)
    File.write!(procfile_path, contents)
    procfile_path
  end

  defp do_unpack_release(%{name: name, version: version} = config) do
    debug "Unpacking release..."
    tmp_dir = create_tmp_dir(config)
    tarball = rel_dest_path [name, "#{name}-#{version}.tar.gz"]
    :erl_tar.extract(tarball, [{:cwd, tmp_dir}, :compressed])
    tmp_dir
  end

  defp do_release_slug(config, slug_dir) do
    heroku_app = config.heroku_app
    args =  ["-dir", slug_dir, "-app", heroku_app, "-release"]
    execute_slug(config.slug_command, args)
  end

  defp create_tmp_dir(config) do
    tmp_dir = System.tmp_dir
    release_tmp_dir = Path.join([tmp_dir, config.name])
    case File.mkdir(release_tmp_dir) do
      :ok ->
        release_tmp_dir
      {:error, :eexist} ->
        File.rm_rf!(release_tmp_dir)
        create_tmp_dir(config)
    end
  end

  defp execute_slug(command, args) do
    IO.puts "Executing: #{command} #{Enum.join(args, " ")}"
    case System.cmd(command, args) do
      {:error, :enoent} ->
        IO.puts """
          slug command wasn't found, please install it and try again.
          Check https://github.com/naaman/slug for more info.
        """
      {:error, error} ->
        IO.puts "Error #{inspect(error)} executing the slug command."
      {output, _} ->
        IO.puts "Command executed, output: \n#{output}"
        output
    end
  end

  defp template_path(filename) do
    priv_path = :code.priv_dir('exrm_heroku')
    Path.join([priv_path, "rel", "files", filename])
  end

  defp get_config_item(config, item, default) do
    project_config = Mix.Project.config |> Keyword.get(:heroku)
    config |> Map.get(item, Keyword.get(project_config, item, default))
  end
end
