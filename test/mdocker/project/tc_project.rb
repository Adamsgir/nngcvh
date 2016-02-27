require_relative '../../test_helper'

module MDocker
  class ProjectTest < Test::Unit::TestCase

    include MDocker::TestBase

    PROJECT_FIXTURE_NAME = 'project'
    PROJECT_LOCK_PATH = 'project/.mdocker/mdocker.lock'

    def with_project(project_name='project')
      with_fixture(PROJECT_FIXTURE_NAME) do |fixture|
        config_data = [{:default.to_s => { :container.to_s => { :user.to_s => Util::stringify_keys(Util::user_info) }}}]
        config_data += ["project/#{project_name}.yml", '.mdocker/settings.yml']
        config = config(fixture, config_data)

        repository = repository(fixture,
                                'Dockerfile',
                                %w(project/.mdocker/dockerfiles .mdocker/dockerfiles),
                                '.mdocker/locks',
                                'project/.mdocker/tmp')

        lock_path = fixture.expand_path File.join('project', '.mdocker', 'mdocker.lock')
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

        config_hash(project)['project']['hostname'] = 'updated'
        assert_equal hash3, project.build_hash

        config_hash(project)['container']['user']['name'] = 'updated'
        assert_not_nil hash4 = project.build_hash
        assert_not_equal hash3, hash4
      end
    end

    # noinspection RubyStringKeysInHashInspection
    def test_docker
      assert_images 'docker', [['os', 'debian:jessie', {}], ['tool_2', 'test_tool_2', {'name_2'=>'value_2'}]]
    end

    def test_docker_not_first
      assert_raise(StandardError) {
        assert_images 'docker_not_first', []
      }
    end

    def test_duplicate_image_label
      assert_raise(StandardError) {
        assert_images 'duplicate_image_label', []
      }
    end

    def test_empty
      user_name = Util::user_info[:name]
      assert_images('empty', [['base', 'debian:jessie', {}]], true, user_name)
    end

    # noinspection RubyStringKeysInHashInspection
    def test_skip_user
      assert_images('skip_user',
                    [['user', 'user', {}], ['os', 'debian:jessie', {}], ['tool_1', 'test_tool_1', {'name_1'=>'value_1'}], ['tool_2', 'test_tool_2', {'name_2'=>'value_2'}]],
                    false)
    end

    def test_missing_image
      assert_raise(IOError) {
        assert_images 'missing_image', []
      }
    end

    # noinspection RubyStringKeysInHashInspection
    def test_project
      assert_images 'project', [['tool_1', 'test_tool_1', {'name_1'=>'value_1'}], ['tool_2', 'test_tool_2', {'name_2'=>'value_2'}]]
    end

    def test_wrong_image
      assert_raise(StandardError) {
        assert_images 'wrong_image', []
      }
    end

    def test_no_images
      assert_images 'no_images', [['base', 'debian:jessie', {}]]
    end

    def test_tags
      assert_images 'tags',[['tag', 'tag', {}], ['os', 'debian:jessie', {}], ['base_tag', 'base_tag', {}], ['base_tag2', 'base_tag2', {}]]
    end

    def assert_images(project_name, expected, include_user=true, user_name='test_user')
      if include_user
        user_contents = File.read(File.join(Util::datadir, 'user'))
        user_args = Util::stringify_keys(Util::user_info)
        user_args['name'] = user_name
        user_args['group'] = user_name
        expected << ['user', user_contents, user_args]
      end

      with_project(project_name) do |_, project|
        assert_equal expected, (project.send(:images) { |label, object, args| [label, object.contents, args] })
      end
    end

  end
end