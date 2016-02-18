require_relative '../test_helper'

module MDocker
  class RepositoryObjectTest < TestBase

    def test_object_load
      @default_fixture.copy { |fixture|
        repository = create_default_repository(fixture)
        [
          {path: fixture.expand_path('file_roaming')},
          {path: fixture.expand_path('directory_roaming')},
          {path: 'file'},
          {path: 'file_project'},
          {path: 'file_global'},
          {path: 'directory'},
          {path: 'directory_project'},
          {path: 'directory_global'},
        ].each { |location|
          obj = repository.object(location)

          assert_not_nil obj
          assert_false obj.has_contents?
          assert_true obj.outdated?

          assert_true obj.fetch

          assert_false obj.outdated?
          assert_true obj.has_contents?

          assert_false obj.fetch

          obj.origin[:paths].each do |path|
            if File.directory? path
              path = File.join(path, DEFAULT_FILE_NAME)
            end
            break File.write(path, File.read(path) + ' modified') if File.file?(path)
          end

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
          {url: fixture.git_url('repository.git'), ref: 'master', path:'file'},
          {url: fixture.git_url('repository.git'), ref: 'master', path:'directory'},
          {url: fixture.git_url('repository.git'), ref: 'master', path:'directory/Dockerfile'},
        ]

        objs.each do |location|
          obj = repository.object(location)
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
          {url: fixture.git_url('missing.git'), ref: 'master', path:'file'},
          {url: fixture.git_url('repository.git'), ref: 'master', path:'missing'},
          {url: fixture.git_url('repository.git'), ref: 'missing', path:'file'},
        ]

        objs.each do |location|
          obj = repository.object(location)
          assert_not_nil obj
          assert_false obj.has_contents?
          assert_true obj.outdated?

          assert_raise { obj.fetch }
        end
      end

    end
  end
end