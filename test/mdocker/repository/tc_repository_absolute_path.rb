require_relative '../../test_helper'

module MDocker
  class RepositoryAbsolutePathTest < Test::Unit::TestCase

    include MDocker::RepositoryTestBase

    def setup
      @locations = [
          {path: 'file_roaming'},
          {path: 'directory_roaming/Dockerfile'},
          {path: '.mdocker/dockerfiles/file'},
          {path: 'project/.mdocker/dockerfiles/file'},
          {path: 'directory_roaming'}
      ]
      @missing_locations = [
          {path: 'abc'},
          {path: '.mdocker'},
          {path: '.mdocker/dockerfiles/directory_empty'},
          {path: 'directory_roaming/Dockerfile/xxx'},
          {path: 'directory_roaming/yyy'},
          {path: '.mdocker/dockerfiles/Dockerfile'}
      ]
      @single_location = {path: 'directory_roaming/Dockerfile'}
    end

    def expand_origin(fixture, location)
      {path: fixture.expand_path(location[:path])}
    end

    def write_origin(fixture, location, contents)
      path = fixture.expand_path(location[:path])
      if File.directory? path
        File.write(File.join(path, 'Dockerfile'), contents)
      else
        File.write(path, contents)
      end
    end

    def read_origin(fixture, location)
      path = fixture.expand_path(location[:path])
      begin
        File.read path
      rescue
        begin
          File.read(File.join(path, 'Dockerfile'))
        end
      end
    end

  end
end