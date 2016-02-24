require_relative '../../test_helper'

module MDocker
  class ConfigTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_config
      config = MDocker::Config.new
      config.load
    end

  end
end