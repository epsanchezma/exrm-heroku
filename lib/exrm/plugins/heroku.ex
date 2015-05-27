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

    procfile_path = Path.expand(Path.join([File.cwd!, "Procfile"]))
    {:ok, process_types} = Exlug.Procfile.parse(procfile_path)

    IO.write "Initializing slug for #{slug_dir}..."
    slug = Exlug.Slug.create(netrc_key, heroku_app, slug_dir, process_types)
    IO.write "done\n"

    IO.write "Archiving #{slug_dir}..."
    slug = Exlug.Slug.archive(slug)
    IO.write "done\n"

    IO.write "Pushing #{slug.tar_file}..."
    Exlug.Slug.push(slug)
    IO.write "done\n"

    IO.write "Releasing..."
    release = Exlug.Slug.release(slug)
    IO.write "done (v#{release.version})\n"
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

  defp template_path(filename) do
    priv_path = :code.priv_dir('exrm_heroku')
    Path.join([priv_path, "rel", "files", filename])
  end

  defp get_config_item(config, item, default) do
    project_config = Mix.Project.config |> Keyword.get(:heroku)
    config |> Map.get(item, Keyword.get(project_config, item, default))
  end

  defp netrc_key do
    Netrc.read["api.heroku.com"]["password"]
  end
end
