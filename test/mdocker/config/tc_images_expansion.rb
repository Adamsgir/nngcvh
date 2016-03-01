require_relative '../../test_helper'

module MDocker
  class ImagesExpansionTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_images_expansion
      with_config('expansion', %w(images.yml)) do |config|
        config.get(:sugar).each do |_, v|
          expanded = ImagesExpansion::expand(v)
          expanded.each { |e| assert_equal v[0], e}
        end
      end
    end

  end
end