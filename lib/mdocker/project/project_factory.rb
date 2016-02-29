module MDocker
  class ProjectFactory

    DOCKER_FILE_NAME = 'Dockerfile'

    def create(opts)
      dot_name = '.' + MDocker::Meta::NAME
      name = MDocker::Meta::NAME

      home_dir = opts[:home] || Dir.home
      current_dir = opts[:pwd] || Dir.pwd
      command = opts[:command]
      update_remote = opts[:update_remote]

      project_dir = look_up(current_dir, name + '.yml')
      raise StandardError.new("no '#{name + '.yml'}' file found") if project_dir.nil?

      config_files = [
        File.join(home_dir, '.config', name, 'settings.yml'),
        File.join(home_dir, dot_name, 'settings.yml'),
        File.join(project_dir, dot_name, 'settings.yml'),
        File.join(project_dir, name + '.yml'),
        File.join(project_dir, dot_name + '.yml')
      ]

      repository_dirs = [
          File.join(project_dir, dot_name, 'dockerfiles'),
          File.join(home_dir, dot_name, 'dockerfiles'),
          File.join(home_dir, '.config', name, 'dockerfiles'),
          MDocker::Util::dockerfiles_dir,
      ]
      repository_lock_dir = File.directory?(File.join(home_dir, '.config')) ?
          File.join(home_dir, '.config', name, 'locks') : File.join(home_dir, dot_name, 'locks')
      repository_temp_dir = File.join(project_dir, dot_name, 'tmp')

      providers = [
          GitRepositoryProvider.new(DOCKER_FILE_NAME, repository_temp_dir),
          AbsolutePathProvider.new(DOCKER_FILE_NAME),
          PathProvider.new(DOCKER_FILE_NAME, repository_dirs),
          DockerProvider.new
      ]
      repository = MDocker::Repository.new(repository_lock_dir, providers, update_remote ? 100 : 0)

      project_opts = { ProjectConfig::WORKING_DIRECTORY_OPT => current_dir,
                       ProjectConfig::PROJECT_DIRECTORY_OPT => project_dir,
                       ProjectConfig::COMMAND_OPT => command }
      project_config = MDocker::ProjectConfig.new(config_files, repository, project_opts)

      project_lock_file = File.join(project_dir, dot_name, name + '.lock')
      MDocker::Project.new(project_config, project_lock_file)
    end

    private

    def look_up(base_path, file_name)
      if File.readable? File.join(base_path, file_name)
        base_path
      else
        if base_path == '/' or base_path == ''
          nil
        else
          look_up(File.dirname(base_path), file_name)
        end
      end
    end

  end
end