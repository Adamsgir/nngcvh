require_relative '../../test_helper'

module MDocker
  class DockerFileTest < Test::Unit::TestCase

    def test_from_override
      file = %q(FROM xxx
              ARG name='value space'
              COPY "./$name/dir space" /usr/$name/dir
              ADD '$name')

      docker_file = DockerFile.new(contents:file, args:{})
      assert_equal %q(FROM yyy
              ARG name='value space'
              COPY "./$name/dir space" /usr/$name/dir
              ADD '$name'), docker_file.with_from('yyy')

    end

    def test_no_from_override
      file = %q(ARG name='value space'
              COPY "./$name/dir space" /usr/$name/dir
              ADD '$name')

      docker_file = DockerFile.new(contents:file, args:{})
      assert_equal %Q(FROM yyy\nARG name='value space'
              COPY "./$name/dir space" /usr/$name/dir
              ADD '$name'), docker_file.with_from('yyy')

    end

  end
end