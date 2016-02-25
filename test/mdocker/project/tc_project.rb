require_relative '../../test_helper'

module MDocker
  class ProjectTest < Test::Unit::TestCase

    include MDocker::TestBase

    PROJECT_FIXTURE_NAME = 'project'
    PROJECT_CONFIG_PATHS = %w(project/mdocker.yml .mdocker/settings.yml)
    PROJECT_LOCK_PATH = 'project/.mdocker/mdocker.lock'

    def setup
      @fixture = fixture('project')
      @config = MDocker::Config.new(PROJECT_CONFIG_PATHS.map {|path| @fixture.expand_path(path)})
      @repository = repository(fixture)
      @project = MDocker::Project.new(@config, @repository, @fixture.expand_path(PROJECT_LOCK_PATH))
    end

    def teardown
      @fixture.delete
    end

    def test_project
      assert_not_nil @project.build_hash
    end

  end
end