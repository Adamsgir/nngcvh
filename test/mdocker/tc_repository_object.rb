require_relative '../test_helper'

class RepositoryObject < Test::Unit::TestCase

  def setup
    @default_fixture = MDocker::Fixture.create('default')
    @default_file_name = 'Dockerfile'
    @default_repository_paths = %w(project/.mdocker/dockerfiles .mdocker/dockerfiles)
  end

  def test_object
    @default_fixture.clone { |fixture|
      repository = MDocker::Repository::new(@default_file_name, fixture.expand_paths(@default_repository_paths))
      obj = repository.get_object('file')

      assert_not_nil obj
      assert_equal false, obj.has_contents?
      assert_equal true, obj.outdated?

      updated = obj.fetch

      assert_equal true, updated

      assert_equal false, obj.outdated?
      assert_equal true, obj.has_contents?

      updated = obj.fetch
      assert_equal false, updated

      File.write(obj.origin, File.read(obj.origin) + ' modified')

      assert_equal true, obj.has_contents?
      assert_equal true, obj.outdated?

      updated = obj.fetch

      assert_equal true, updated

      assert_equal false, obj.outdated?
      assert_equal true, obj.has_contents?
    }
  end


end