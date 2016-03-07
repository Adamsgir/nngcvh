module MDocker
  module TestBase

    DEFAULT_FIXTURE_NAME = 'default'
    DEFAULT_FILE_NAME = 'Dockerfile'
    DEFAULT_REPOSITORY_PATHS = %w(project/.mdocker/dockerfiles .mdocker/dockerfiles)
    DEFAULT_LOCK_PATH = '.mdocker/locks'
    DEFAULT_TMP_LOCATION = 'project/.mdocker/tmp'
    DEFAULT_CONFIG_PATHS = %w(project/.mdocker.yml project/mdocker.yml project/.mdocker/settings.yml .mdocker/settings.yml).reverse

    CONTAINER_FIXTURE_NAME = 'container'

    def fixture(fixture_name=DEFAULT_FIXTURE_NAME)
      Fixture.create(fixture_name).copy
    end

    def with_fixture(fixture_name=DEFAULT_FIXTURE_NAME)
      fixture = fixture(fixture_name)
      yield fixture
      fixture.delete
    end

    def repository(fixture, file_name=DEFAULT_FILE_NAME, repository_paths=DEFAULT_REPOSITORY_PATHS, locks_path=DEFAULT_LOCK_PATH, git_tmp_path=DEFAULT_TMP_LOCATION)
      providers = [
          GitRepositoryProvider.new(file_name, fixture.expand_path(git_tmp_path)),
          AbsolutePathProvider.new(file_name),
          PathProvider.new(file_name, fixture.expand_paths(repository_paths)),
          DockerProvider.new
      ]
      expensive_provider = providers.max_by { |provider| provider.update_price }
      MDocker::Repository.new(fixture.expand_path(locks_path), providers, expensive_provider.update_price)
    end

    def with_repository(fixture_name=DEFAULT_FIXTURE_NAME, file_name=DEFAULT_FILE_NAME, repository_paths=DEFAULT_REPOSITORY_PATHS, locks_path=DEFAULT_LOCK_PATH, git_tmp_path=DEFAULT_TMP_LOCATION)
      with_fixture(fixture_name) do |fixture|
        yield fixture, repository(fixture, file_name, repository_paths, locks_path, git_tmp_path)
      end
    end

    def config(fixture, config_data)
      if Array === config_data
        MDocker::Config.new(config_data.map { |data| String === data ? fixture.expand_path(data) : data })
      else
        MDocker::Config.new(config_data)
      end
    end

    def with_config(fixture_name, config_data=DEFAULT_CONFIG_PATHS)
      with_fixture(fixture_name) do |fixture|
        yield config(fixture, config_data)
      end
    end

    def with_container_config(fixture_name: CONTAINER_FIXTURE_NAME, name: 'project', base: 'settings')
      with_fixture(fixture_name) do |fixture|

        repository = repository(fixture,
                                'Dockerfile',
                                %w(project/.mdocker/dockerfiles .mdocker/dockerfiles),
                                '.mdocker/locks',
                                'project/.mdocker/tmp')

        config_paths = %W(.mdocker/#{base}.yml project/#{name}.yml)
        defaults =
            {
                host:
                {
                 user: Util::user_info,
                 project:
                     {
                         path: fixture.expand_path('project'),
                     },
                 pwd: fixture.expand_path('project'),
                },
            }
        defaults[:host][:user][:home] = Dir.home

        config = MDocker::ConfigFactory.new.create(*fixture.expand_paths(config_paths))
        config = MDocker::ConfigFactory.new.create(*[config.get(:project, default: {})], defaults: defaults)
        container_config = MDocker::ContainerConfig.new(config)

        yield fixture, container_config, repository
      end
    end

  end
end