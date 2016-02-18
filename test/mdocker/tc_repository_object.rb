require_relative '../test_helper'

module MDocker
  class RepositoryObjectTest < TestBase

    def test_object_load
      @default_fixture.copy { |fixture|
        repository = create_default_repository(fixture)
        [
          fixture.expand_path('file_roaming'),
          fixture.expand_path('directory_roaming'),
          'file',
          'file_project',
          'file_global',
          'directory',
          'directory_project',
          'directory_global',
        ].each { |location|
          obj = repository.get_object(location)

          assert_not_nil obj
          assert_false obj.has_contents?
          assert_true obj.outdated?

          assert_true obj.fetch

          assert_false obj.outdated?
          assert_true obj.has_contents?

          assert_false obj.fetch

          File.write(obj.origin, File.read(obj.origin) + ' modified')

          assert_true obj.has_contents?
          assert_true obj.outdated?

          assert_true obj.fetch

          assert_false   obj.outdated?
          assert_true obj.has_contents?
        }

      }
    end

    def test_git_object_load
      @default_fixture.copy do |fixture|
        repository = create_default_repository(fixture)
        objs = [
          'file://' + fixture.expand_path('repository.git') + '|master|file',
          'file://' + fixture.expand_path('repository.git') + '|master',
          'file://' + fixture.expand_path('repository.git') + '|master|directory',
          'file://' + fixture.expand_path('repository.git') + '|master|directory/Dockerfile'
        ]

        objs.each do |location|
          obj = repository.get_object(location)
          assert_not_nil obj
          assert_false obj.has_contents?
          assert_true obj.outdated?

          updated = obj.fetch

          assert_true updated
          assert_true obj.has_contents?
          assert_equal 'file', obj.contents
        end
      end
    end

    def test_git_object_load_fail
      @default_fixture.copy do |fixture|
        repository = create_default_repository(fixture)
        objs = [
          'file://' + fixture.expand_path('missing.git') + '|master|file',
          'file://' + fixture.expand_path('repository.git') + '|master|missing',
          'file://' + fixture.expand_path('repository.git') + '|missing|file'
        ]

        objs.each do |location|
          obj = repository.get_object(location)
          assert_not_nil obj
          assert_false obj.has_contents?
          assert_true obj.outdated?

          assert_raise { obj.fetch }
        end
      end

    end
  end
end