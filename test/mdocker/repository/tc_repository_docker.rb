require_relative '../../test_helper'
require 'digest'

module MDocker
  class RepositoryDockerTest < Test::Unit::TestCase

    include MDocker::TestBase

    def setup
      @locations = [
          {docker: 'debian:jessie'},
      ]
    end

    def test_file_from_datadir
      with_repository do |_, repository|
        @locations.each do |location|

          obj = repository.object(location)
          assert_not_nil obj

          assert_false obj.has_contents?
          assert_true obj.outdated?

          assert_true obj.fetch
          assert_true obj.has_contents?
          assert_false obj.outdated?
          assert_equal location[:docker], obj.contents
        end
      end
    end

  end
end