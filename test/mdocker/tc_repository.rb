require_relative '../test_helper'

module MDocker
  class RepositoryTest < TestBase

    def test_absolute_path
      fixture = @default_fixture
      repository = @default_repository

      [
        {path: 'file_roaming'},
        {path: 'directory_roaming/Dockerfile'},
        {path: '.mdocker/dockerfiles/file'},
        {path: 'project/.mdocker/dockerfiles/file'}
      ].each { |location|
        location[:path] = fixture.expand_path(location[:path])
        obj = repository.get_object(location)
        assert_instance_of MDocker::RepositoryObject, obj
      }
      [
        {path: 'directory_roaming'}
      ].each { |location|
        location[:path] = fixture.expand_path(location[:path])
        obj = repository.get_object(location)
        assert_instance_of MDocker::RepositoryObject, obj
      }
    end

    def test_missing_absolute_path
      fixture = @default_fixture
      repository = @default_repository

      [
        {path: 'abc'},
        {path: '.mdocker'},
        {path: '.mdocker/dockerfiles/directory_empty'},
        {path: 'directory_roaming/Dockerfile/xxx'},
        {path: 'directory_roaming/yyy'},
        {path: '.mdocker/dockerfiles/Dockerfile'}
      ].each { |location|
        location[:path] = fixture.expand_path location[:path]
        obj = repository.get_object(location)
        assert_true obj.outdated?
        assert_false obj.has_contents?
        assert_raise { obj.fetch }
      }
    end

    def test_relative_path
      repository = @default_repository

      [
        {path: 'file'},
        {path: 'file_project'},
        {path: 'file_global'},
        {path: 'directory/file'},
        {path: 'directory/Dockerfile'},
        {path: 'directory/sub/Dockerfile'},
        {path: 'directory_project/Dockerfile'},
        {path: 'directory_global/Dockerfile'}
      ].each { |location|
        obj = repository.get_object(location)
        assert_not_nil obj
        assert_instance_of MDocker::RepositoryObject, obj
      }

      [
        {path: 'directory'},
        {path: 'directory_project'},
        {path: 'directory_global'},
        {path: 'directory/sub'},
      ].each { |location|
        obj = repository.get_object(location)
        assert_not_nil obj
        assert_instance_of MDocker::RepositoryObject, obj
      }
    end

    def test_lock_paths
      fixture = @default_fixture
      repository = @default_repository

      global_repository_path = fixture.expand_path default_repository_paths[1]

      obj = repository.get_object({path: 'file'})
      assert_true obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)

      obj = repository.get_object({path: 'file_global'})
      assert_true obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)

      obj = repository.get_object({path: 'file_project'})
      assert_true obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)

      obj = repository.get_object({path: fixture.expand_path('file_roaming')})
      assert_true obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)
    end

  end
end