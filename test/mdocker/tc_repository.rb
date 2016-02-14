require_relative '../test_helper'

class RepositoryTest < Test::Unit::TestCase

  def setup
    @default_fixture = MDocker::Fixture.new('default')
    @default_file_name = 'Dockerfile'
    @default_repository_paths = %w(project/.mdocker/dockerfiles .mdocker/dockerfiles)
    @default_repository = MDocker::Repository.new('Dockerfile', @default_fixture.expand_paths(@default_repository_paths))
  end

  def test_create_empty
    assert_raise(ArgumentError) {
      [MDocker::Repository.new('Dockerfile', [])].each { |repository|
        assert_not_nil repository.paths
        assert_equal 0, repository.paths.size
      }
    }
  end

  def test_create
    fixture = @default_fixture
    repository = @default_repository

    assert_not_nil repository.paths
    assert_equal @default_repository_paths.size, repository.paths.size
    repository.paths.each_with_index { |path, index|
      assert_equal fixture.expand_path(@default_repository_paths[index]), path
    }
  end

  def test_absolute_path
    fixture = @default_fixture
    repository = @default_repository

    %w(
        file_roaming
        directory_roaming/Dockerfile
        .mdocker/dockerfiles/file
        project/.mdocker/dockerfiles/file
      ).each { |path|
      lock = repository.get_lock(fixture.expand_path(path))
      assert_instance_of MDocker::RepositoryLock, lock
    }
    %w(
        directory_roaming
      ).each { |path|
      lock = repository.get_lock(fixture.expand_path(path))
      assert_instance_of MDocker::RepositoryLock, lock
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
      assert_nil repository.get_lock(fixture.expand_path path)
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
      lock = repository.get_lock(path)
      assert_not_nil lock
      assert_instance_of MDocker::RepositoryLock, lock
    }

    %w(
        directory
        directory_project
        directory_global
        directory/sub
      ).each { |path|
      lock = repository.get_lock(path)
      assert_not_nil lock
      assert_instance_of MDocker::RepositoryLock, lock
    }
  end

  def test_lock_paths
    fixture = @default_fixture
    repository = @default_repository

    project_repository_path =fixture.expand_path @default_repository_paths[0]
    global_repository_path = fixture.expand_path @default_repository_paths[1]

    lock = repository.get_lock 'file'
    assert_equal true, lock.origin.start_with?(project_repository_path + File::SEPARATOR)
    assert_equal true, lock.lock_path.start_with?(global_repository_path + File::SEPARATOR)

    lock = repository.get_lock 'file_global'
    assert_equal true, lock.origin.start_with?(global_repository_path + File::SEPARATOR)
    assert_equal true, lock.lock_path.start_with?(global_repository_path + File::SEPARATOR)

    lock = repository.get_lock 'file_project'
    assert_equal true, lock.origin.start_with?(project_repository_path + File::SEPARATOR)
    assert_equal true, lock.lock_path.start_with?(global_repository_path + File::SEPARATOR)

    lock = repository.get_lock(fixture.expand_path 'file_roaming')
    assert_equal lock.origin, fixture.expand_path('file_roaming')
    assert_equal true, lock.lock_path.start_with?(global_repository_path + File::SEPARATOR)
  end

end