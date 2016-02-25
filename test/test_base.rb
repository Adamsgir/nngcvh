module MDocker
  module TestBase

    DEFAULT_FIXTURE_NAME = 'default'
    DEFAULT_FILE_NAME = 'Dockerfile'
    DEFAULT_REPOSITORY_PATHS = %w(project/.mdocker/dockerfiles .mdocker/dockerfiles)
    DEFAULT_LOCK_PATH = '.mdocker/locks'
    DEFAULT_TMP_LOCATION = 'project/.mdocker/tmp'

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
      ]
      expensive_provider = providers.max_by { |provider| provider.update_price }
      MDocker::Repository.new(fixture.expand_path(locks_path), providers, expensive_provider.update_price)
    end

    def with_repository(fixture_name=DEFAULT_FIXTURE_NAME, file_name=DEFAULT_FILE_NAME, repository_paths=DEFAULT_REPOSITORY_PATHS, locks_path=DEFAULT_LOCK_PATH, git_tmp_path=DEFAULT_TMP_LOCATION)
      with_fixture(fixture_name) do |fixture|
        yield fixture, repository(fixture, file_name, repository_paths, locks_path, git_tmp_path)
      end
    end
  end
end