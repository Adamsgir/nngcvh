require 'digest/sha1'

module MDocker
  class Project

    attr_reader :config

    def initialize(project_config, lock_path=nil)
      @config = project_config
      @lock_path = lock_path
    end

    def build_hash(update_threshold=0)
      digest = Digest::SHA1.new
      digest.update(@config.name)
      @config.images(update_threshold) do |label, object, args|
        digest.update(label)
        digest.update(object.contents)
        digest.update(args.to_s)
      end
      digest.hexdigest!
    end

  end
end