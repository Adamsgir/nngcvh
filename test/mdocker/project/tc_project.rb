require_relative '../../test_helper'

module MDocker
  class ProjectTest < Test::Unit::TestCase

    include MDocker::TestBase

    PROJECT_FIXTURE_NAME = 'project'
    PROJECT_CONFIG_PATHS = %w(project/mdocker.yml .mdocker/settings.yml)
    PROJECT_LOCK_PATH = 'project/.mdocker/mdocker.lock'

    def with_project(project_name='project')
      with_fixture(PROJECT_FIXTURE_NAME) do |fixture|
        config_paths = fixture.expand_paths ["project/#{project_name}.yml", '.mdocker/settings.yml']
        lock_path = fixture.expand_path File.join('project', '.mdocker', 'mdocker.lock')
        config = MDocker::Config.new(config_paths)

        repository = repository(fixture,
                                'Dockerfile',
                                %w(project/.mdocker/dockerfiles .mdocker/dockerfiles),
                                '.mdocker/locks',
                                'project/.mdocker/tmp')

        project = MDocker::Project.new(config, repository, lock_path)
        yield fixture, project
      end
    end

    def config_hash(project)
      config = project.instance_variable_get('@config')
      config.instance_variable_get('@config')
    end

    def test_project_hash_changes
      with_project do |fixture, project|
        assert_not_nil hash = project.build_hash
        assert_equal hash, project.build_hash

        fixture.write('project/.mdocker/dockerfiles/test_tool_1', 'updated')

        assert_not_nil hash2 = project.build_hash
        assert_not_equal hash, hash2

        config_hash(project)['image'][0]['args']['name_1'] = 'updated'

        assert_not_nil hash3 = project.build_hash
        assert_not_equal hash, hash3
        assert_not_equal hash2, hash3

        config_hash(project)['project']['name'] = 'updated'
        assert_equal hash3, project.build_hash
      end
    end

  end
end