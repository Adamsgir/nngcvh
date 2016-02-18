require_relative '../../test_helper'

module MDocker
  class RepositoryRelativePathTest < Test::Unit::TestCase

    include MDocker::TestBase
    include MDocker::RepositoryTestBase

    def setup
      @locations = [
          {path: 'file'},
          {path: 'file_project'},
          {path: 'file_global'},
          {path: 'directory/file'},
          {path: 'directory/Dockerfile'},
          {path: 'directory/sub/Dockerfile'},
          {path: 'directory_project/Dockerfile'},
          {path: 'directory_global/Dockerfile'},
          {path: 'directory'},
          {path: 'directory_project'},
          {path: 'directory_global'},
          {path: 'directory/sub'},
      ]

      @missing_locations = [
          {path: 'abc'},
          {path: '.mdocker'},
          {path: '.mdocker/dockerfiles/directory_empty'},
          {path: 'directory_roaming/Dockerfile/xxx'},
          {path: 'directory_roaming/yyy'},
          {path: '.mdocker/dockerfiles/Dockerfile'}
      ]
      @single_location = {path: 'directory/Dockerfile'}
    end

    # noinspection RubyUnusedLocalVariable
    def expand_origin(fixture, location)
      location
    end

    def write_origin(fixture, location, contents)
      path = location[:path]
      path = File.join(DEFAULT_REPOSITORY_PATHS[0], path)
      path = fixture.expand_path path

      FileUtils::mkdir_p File.dirname(path)

      if File.directory? path
        File.write(File.join(path, 'Dockerfile'), contents)
      else
        File.write(path, contents)
      end
    end

    def read_origin(fixture, location)
      contents = DEFAULT_REPOSITORY_PATHS.detect do |repository_path|
        path = fixture.expand_path File.join(repository_path, location[:path])
        if File.directory? path
          path = File.join(path, 'Dockerfile')
        end
        break File.read(path) if File.file?(path) && File.readable?(path)
      end
      raise IOError.new('file not found') if contents.nil?
      contents
    end

    def test_local_repository_priority
      with_repository do |fixture, repository|
        obj = repository.object(@single_location)
        assert_not_nil obj
        assert_true (obj.outdated? && !obj.has_contents?)
        assert_true obj.fetch
        assert_equal read_origin(fixture, @single_location), obj.contents
        assert_true (!obj.outdated? && obj.has_contents?)

        contents = read_origin(fixture, @single_location)

        # change global
        path = File.join(DEFAULT_REPOSITORY_PATHS[1], @single_location[:path])
        path = fixture.expand_path path
        File.write(path, contents * 2)

        assert_true (!obj.outdated? && obj.has_contents?)
        assert_false obj.fetch
        assert_equal contents, obj.contents
        assert_true (!obj.outdated? && obj.has_contents?)

        # change local
        write_origin(fixture, @single_location, contents * 2)

        assert_true (obj.outdated? && obj.has_contents?)
        assert_true obj.fetch
        assert_equal contents * 2, obj.contents
        assert_true (!obj.outdated? && obj.has_contents?)

      end
    end

  end
end