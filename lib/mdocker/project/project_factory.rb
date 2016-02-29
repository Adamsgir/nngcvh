module MDocker
  class ProjectFactory

    DOCKER_FILE_NAME = 'Dockerfile'

    def create(opts={})
      opts ||= {}
      opts[:home] ||= Dir.home
      opts[:pwd] ||= Dir.pwd

      home_dir = opts[:home]
      current_dir = opts[:pwd]
      update_remote = opts[:update_remote]

      dot_name = '.' + MDocker::Meta::NAME
      name = MDocker::Meta::NAME

      opts[:project] ||= look_up(current_dir, name + '.yml')
      project_dir = opts[:project]
      raise StandardError.new("no '#{name + '.yml'}' file found") unless opts[:project]

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
          DockerProvider.new,
      ]
      repository = MDocker::Repository.new(repository_lock_dir, providers, update_remote ? 100 : 0)

      config_files = [
          File.join(home_dir, '.config', name, 'settings.yml'),
          File.join(home_dir, dot_name, 'settings.yml'),
          File.join(project_dir, dot_name, 'settings.yml'),
          File.join(project_dir, name + '.yml'),
          File.join(project_dir, dot_name + '.yml')
      ]
      project_config = MDocker::ProjectConfig.new([host_configuration(opts)] + config_files + [user_configuration(opts)], repository)

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

    def host_configuration(opts)
      user_info = MDocker::Util::user_info
      user_home = File.expand_path(opts[:home])
      { project: { host: {
          working_directory: File.expand_path(opts[:pwd]),
          project_directory: File.expand_path(opts[:project]),
          user: {
              name: user_info[:name],
              uid: user_info[:uid],
              gid: user_info[:gid],
              home: user_home
          },
          docker: {
              path: 'docker'
          }
      }}}
    end

    def user_configuration(opts)
      opts[:command] ?
      { project: { container: {
          command: opts[:command]
      }}} : {}
    end

  end
end