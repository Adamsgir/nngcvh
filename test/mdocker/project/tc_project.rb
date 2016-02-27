require_relative '../../test_helper'

module MDocker
  class ProjectTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_project_hash_changes
      with_project do |fixture, project|
        assert_not_nil hash = project.build_hash
        assert_equal hash, project.build_hash

        fixture.write('project/.mdocker/dockerfiles/test_tool_1', 'updated')

        assert_not_nil hash2 = project.build_hash
        assert_not_equal hash, hash2

        project.config.config.raw[:image][0][:args][:name_1] = 'updated'

        assert_not_nil hash3 = project.build_hash
        assert_not_equal hash, hash3
        assert_not_equal hash2, hash3

        project.config.config.raw[:project][:hostname] = 'updated'
        assert_equal hash3, project.build_hash

        project.config.config.raw[:container][:user][:name] = 'updated'
        assert_not_nil hash4 = project.build_hash
        assert_not_equal hash3, hash4
      end
    end

  end
end