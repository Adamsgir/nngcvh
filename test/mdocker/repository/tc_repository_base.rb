require_relative '../../test_helper'

module MDocker
  module RepositoryTestBase

    include MDocker::TestBase

    def test_object_creation
      with_repository do |fixture, repository|
        obj = repository.object(expand_origin(fixture, @single_location))
        assert_not_nil obj
        assert_instance_of RepositoryObject, obj
        assert_true obj.outdated?
        assert_false obj.has_contents?
        assert_nil obj.contents
      end
    end

    def test_object_identity
      with_repository do |fixture, repository|
        obj1 = repository.object(expand_origin(fixture, @single_location))
        obj2 = repository.object(expand_origin(fixture, @single_location))

        assert_false obj1 == obj2

        assert_not_nil obj1
        assert_not_nil obj2
        assert_instance_of RepositoryObject, obj1
        assert_instance_of RepositoryObject, obj2

        assert_true obj1.outdated?
        assert_true obj2.outdated?

        assert_false obj1.has_contents?
        assert_false obj2.has_contents?

        assert_nil obj1.contents
        assert_equal obj1.contents, obj2.contents

        assert_true obj1.fetch
        assert_true obj1.has_contents?
        assert_false obj1.outdated?
        assert_true obj2.has_contents?
        assert_false obj2.outdated?
        assert_equal obj1.contents, obj2.contents
        assert_false obj2.fetch
        assert_equal obj1.contents, obj2.contents
      end
    end

    def test_object_load(locations=nil)
      locations = locations.nil? ?  @locations : locations
      with_repository do |fixture, repository|
        locations.each do |location|
          contents = read_origin(fixture, location)
          obj = repository.object(expand_origin(fixture, location))
          assert_not_nil obj
          obj.fetch
          assert_true obj.has_contents?
          assert_false obj.outdated?
          assert_equal obj.contents, contents
        end
      end
    end

    def test_object_reload
      with_repository do |fixture, repository|
        @locations.each do |location|
          contents = read_origin(fixture, location)
          obj = repository.object(expand_origin(fixture, location))
          assert_not_nil obj
          obj.fetch
          assert_true obj.has_contents?
          assert_false obj.outdated?
          assert_equal obj.contents, contents

          write_origin(fixture, location, contents * 2)

          obj2 = repository.object(expand_origin(fixture, location))

          assert_true obj.has_contents?
          assert_true obj.outdated?

          assert_true obj2.has_contents?
          assert_true obj2.outdated?
          assert_equal obj2.contents, contents

          assert_true obj.fetch

          assert_true obj.has_contents?
          assert_false obj.outdated?
          assert_equal obj.contents, contents * 2
          assert_false obj.fetch
        end
      end
    end

    def test_object_missing
      with_repository do |fixture, repository|
        @missing_locations.each do |location|
          assert_raise { read_origin(fixture, location) }
          obj = repository.object(expand_origin(fixture, location))
          assert_not_nil obj
          assert_false obj.has_contents?
          assert_true obj.outdated?
          assert_raise { obj.fetch }
        end
      end
    end

  end
end