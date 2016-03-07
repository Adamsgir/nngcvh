require_relative '../../test_helper'

module MDocker
  class VolumesExpansionTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_volumes_expansion
      with_config('expansion', %w(volumes.yml)) do |config|
        config = config.set(:host, :home, Dir.home)
        config.get(:sugar).each do |_, v|
          expanded = VolumesExpansion::expand(v, root: config.get(:host, :project))
          expanded.each { |e| assert_equal v[0], e}
        end
      end
    end

  end
end