require_relative '../test_helper'

module MDocker
  class RepositoryTest < TestBase

    def test_absolute_path
      fixture = @default_fixture
      repository = @default_repository

      %w(
          file_roaming
          directory_roaming/Dockerfile
          .mdocker/dockerfiles/file
          project/.mdocker/dockerfiles/file
        ).each { |path|
        obj = repository.get_object(fixture.expand_path(path))
        assert_instance_of MDocker::RepositoryObject, obj
      }
      %w(
          directory_roaming
        ).each { |path|
        obj = repository.get_object(fixture.expand_path(path))
        assert_instance_of MDocker::RepositoryObject, obj
      }
    end

    def test_missing_absolute_path
      fixture = @default_fixture
      repository = @default_repository

      %w(
          abc
          .mdocker
          .mdocker/dockerfiles/directory_empty
          directory_roaming/Dockerfile/xxx
          directory_roaming/yyy
          .mdocker/dockerfiles/Dockerfile
        ).each { |path|
        obj = repository.get_object(fixture.expand_path path)
        assert_true obj.outdated?
        assert_false obj.has_contents?
        assert_raise { obj.fetch }
      }
    end

    def test_relative_path
      repository = @default_repository

      %w(
          file
          file_project
          file_global
          directory/file
          directory/Dockerfile
          directory/sub/Dockerfile
          directory_project/Dockerfile
          directory_global/Dockerfile
        ).each { |path|
        obj = repository.get_object(path)
        assert_not_nil obj
        assert_instance_of MDocker::RepositoryObject, obj
      }

      %w(
          directory
          directory_project
          directory_global
          directory/sub
        ).each { |path|
        obj = repository.get_object(path)
        assert_not_nil obj
        assert_instance_of MDocker::RepositoryObject, obj
      }
    end

    def test_lock_paths
      fixture = @default_fixture
      repository = @default_repository

      project_repository_path =fixture.expand_path default_repository_paths[0]
      global_repository_path = fixture.expand_path default_repository_paths[1]

      obj = repository.get_object 'file'
      assert_equal true, obj.origin.start_with?(project_repository_path + File::SEPARATOR)
      assert_equal true, obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)

      obj = repository.get_object 'file_global'
      assert_equal true, obj.origin.start_with?(global_repository_path + File::SEPARATOR)
      assert_equal true, obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)

      obj = repository.get_object 'file_project'
      assert_equal true, obj.origin.start_with?(project_repository_path + File::SEPARATOR)
      assert_equal true, obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)

      obj = repository.get_object(fixture.expand_path 'file_roaming')
      assert_equal obj.origin, fixture.expand_path('file_roaming')
      assert_equal true, obj.lock_path.start_with?(global_repository_path + File::SEPARATOR)
    end

  end
end