module MDocker
  class TestBase < Test::Unit::TestCase

    DEFAULT_FIXTURE_NAME = 'default'
    DEFAULT_FILE_NAME = 'Dockerfile'
    DEFAULT_LOCATIONS = %w(project/.mdocker/dockerfiles .mdocker/dockerfiles)
    DEFAULT_REPOSITORY_LOCATION = DEFAULT_LOCATIONS.last

    def setup
      @default_fixture = create_default_fixture
      @default_repository = create_default_repository(@default_fixture)
    end

    protected

    def default_repository_paths
      DEFAULT_LOCATIONS
    end

    def create_default_fixture
      MDocker::Fixture.create DEFAULT_FIXTURE_NAME
    end

    def create_absolute_path_provider(file_name=DEFAULT_FILE_NAME)
      AbsolutePathProvider.new(file_name)
    end

    def create_relative_path_provider(fixture, locations=DEFAULT_LOCATIONS, file_name=DEFAULT_FILE_NAME)
      RelativePathProvider.new(file_name, fixture.expand_paths(locations))
    end

    def create_all_providers(fixture, locations=DEFAULT_LOCATIONS, file_name=DEFAULT_FILE_NAME)
      [
          create_absolute_path_provider(file_name),
          create_relative_path_provider(fixture, locations, file_name)
      ]
    end

    def create_default_repository(fixture, locations=DEFAULT_LOCATIONS, file_name=DEFAULT_FILE_NAME)
      create_repository(fixture, create_all_providers(fixture, locations, file_name))
    end

    def create_repository(fixture, providers, location=DEFAULT_REPOSITORY_LOCATION)
      Repository.new(fixture.expand_path(location), providers)
    end
  end
end