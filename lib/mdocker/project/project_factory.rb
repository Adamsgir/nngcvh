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
      config = MDocker::ConfigFactory.new.create(*config_files,
                                          defaults: project_defaults(opts),
                                          overrides: project_overrides(opts))
      project_config = MDocker::ProjectConfig.new(config)

      project_lock_file = File.join(project_dir, dot_name, name + '.yml')
      MDocker::Project.new(project_config, lock_path:project_lock_file, repository: repository)
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

    def project_defaults(opts)
      user_info = MDocker::Util::user_info
      user_home = File.expand_path(opts[:home])
      {project:
        {
            name: Meta::NAME,
            docker: { path: 'docker' },
            host: {
              project: {
                path: File.expand_path(opts[:project]),
              },
              pwd: File.expand_path(opts[:pwd]),
              user: {
                  name: user_info[:name],
                  group: user_info[:group],
                  gid: user_info[:gid],
                  uid: user_info[:uid],
                  home: user_home,
              },
            },
            images: [],
            ports: [],
            volumes: []
        }
      }
    end

    def project_overrides(opts)
      opts[:command] ? { project: {command: opts[:command] }} : {}
    end

    def container_defaults
      {
        # defaults to project docker spec
        docker: '%{project/docker}',
        # defaults to project host spec
        host: {
          project: {
            path: '%{project/host/project/path}',
          },
          pwd: '%{project/host/pwd}'
        },
        container: {
          # defaults to container name
          hostname: '%{../../name}',
          detach: true,
          interactive: false,
          user: {
            name: '%{project/host/user/name}',
            uid: '%{project/host/user/uid}',
            gid: '%{project/host/user/gid}',
            # defaults to container user name
            group: '%{../name}',
            # defaults to home/container_user_name
            home: '/home/%{../name}'
          }
        },
        images: [],
        ports: [],
        # map project dir to container project dir
        volumes: [{
          host: '%{../../host/project/path}',
          container: '%{../../container/project/path}'
        }],
      }
    end
  end
end