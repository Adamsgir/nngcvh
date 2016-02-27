require 'digest/sha1'

module MDocker
  class Project

    attr_reader :config

    def initialize(project_config, lock_path=nil)
      @config = project_config
      @lock_path = lock_path
    end

    def build_hash
      digest = Digest::SHA1.new
      digest.update(@config.name)
      digest = @config.images.inject(digest) do |d, image|
        d.update(image[:label])
        d.update(image[:contents])
        d.update(image[:args].to_s)
      end
      digest.hexdigest!
    end

  end
end