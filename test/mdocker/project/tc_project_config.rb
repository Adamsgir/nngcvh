require_relative '../../test_helper'

module MDocker
  class ProjectConfigTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_docker
      assert_images 'docker', [['os', 'debian:jessie', {}], ['tool_2', 'test_tool_2', {:name_2 =>'value_2'}]]
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
      assert_raise(StandardError) {
        assert_images 'empty', []
      }
    end

    def test_skip_user
      assert_images('skip_user',
                    [['os', 'debian:jessie', {}],
                     ['tool_1', 'test_tool_1', {:name_1 =>'value_1'}],
                     ['tool_2', 'test_tool_2', {:name_2 =>'value_2'}],
                     ],
                    false)
    end

    def test_missing_image
      assert_raise(IOError) {
        assert_images 'missing_image', []
      }
    end

    def test_project
      assert_images 'project', [['tool_1', 'test_tool_1', {:name_1 =>'value_1'}], ['tool_2', 'test_tool_2', {:name_2 =>'value_2'}]]
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
      assert_images 'tags',[['os', 'debian:jessie', {}], ['base_tag', 'base_tag', {}], ['base_tag2', 'base_tag2', {}]]
    end

    def test_volumes
      host_home = Dir.home
      container_home = '/home/test_user'
      with_project_config(name: 'volumes') do |fixture, config|
        expected = [
            {host: "#{host_home}/host", container: "#{container_home}/host"},
            {host: '/host', container: '/host'},
            {host: "#{host_home}/.host", container: "#{container_home}/.container"},
            {host: 'named', container: '/container'},
            {host: '10', container: '/10'},
            {host: '10.1', container: '/10.1'},
            {host: '11', container: "#{container_home}/11"},
            {host: 'true', container: '/true'},
            {host: 'false', container: '/false'},
            {host: fixture.expand_path('project'), container: fixture.expand_path('project') }
        ]
        assert_equal expected, config.volumes
      end
    end

    def test_named_volume_no_path
      assert_raise(StandardError) {
        with_project_config(name: 'volumes_named_no_path') do |_, config|
          config.volumes
        end
      }
      assert_raise(StandardError) {
        with_project_config(name: 'volumes_named_no_path2') do |_, config|
          config.volumes
        end
      }
    end

    def test_duplicated_volumes
      assert_raise(StandardError) {
        with_project_config(name: 'volumes_duplicate_container') do |_, config|
          config.volumes
        end
      }
      assert_raise(StandardError) {
        with_project_config(name: 'volumes_duplicate_host') do |_, config|
          config.volumes
        end
      }
    end

    def assert_images(project_name, expected, include_user=true, user_name='test_user')
      if include_user
        user_contents = File.read(File.join(Util::dockerfiles_dir, 'user'))
        user_args = Util::user_info
        user_args[:name] = user_name
        user_args[:group] = user_name
        user_args[:home] = '/home/' + user_name
        expected << ['latest', user_contents, user_args]
      else
        expected << ['latest', 'latest', {}]
      end

      with_project_config(name: project_name) do |_, config|
        assert_equal expected, (config.images do |image|
          [image[:label], image[:contents], image[:args]]
        end)
      end
    end

  end
end