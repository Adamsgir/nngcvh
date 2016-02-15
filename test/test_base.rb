module MDocker
  class TestBase < Test::Unit::TestCase

    DEFAULT_FIXTURE_NAME = 'default'
    DEFAULT_FILE_NAME = 'Dockerfile'
    DEFAULT_LOCATIONS = %w(project/.mdocker/dockerfiles .mdocker/dockerfiles)

    def setup
      @default_fixture = create_default_fixture
      @default_repository = create_repository(@default_fixture, default_repository_paths)
    end

    protected

    def default_repository_paths
      DEFAULT_LOCATIONS
    end

    def create_default_fixture
      MDocker::Fixture.create DEFAULT_FIXTURE_NAME
    end

    def create_default_repository(fixture)
      create_repository(fixture, default_repository_paths)
    end

    def create_repository(fixture, locations=DEFAULT_LOCATIONS, filename=DEFAULT_FILE_NAME)
      providers = [
          AbsolutePathProvider.new(filename),
          RelativePathProvider.new(filename, fixture.expand_paths(locations))
      ]
      Repository.new(fixture.expand_path(locations.last), providers)
    end
  end
end