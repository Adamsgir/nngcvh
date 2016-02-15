require_relative '../test_helper'

module MDocker
  class RepositoryObjectTest < TestBase

    def test_object_load
      @default_fixture.clone { |fixture|
        repository = create_default_repository(fixture)
        [
          File.join(fixture.root_path, 'file_roaming'),
          File.join(fixture.root_path, 'directory_roaming'),
          'file',
          'file_project',
          'file_global',
          'directory',
          'directory_project',
          'directory_global',
        ].each { |location|
          obj = repository.get_object(location)

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

      }
    end
  end
end