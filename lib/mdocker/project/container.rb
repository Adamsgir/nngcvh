require 'digest/sha1'
require 'yaml'

module MDocker
  class Container

    attr_reader :container_config

    def initialize(container_config, docker:nil)
      @container_config = container_config
      @docker = docker
    end

    def build_hash
      digest = Digest::SHA1.new
      digest.update(@container_config.name)
      digest = @container_config.images.inject(digest) do |d, image|
        d.update(image[:name])
        contents = image[:image][:contents] || image[:image][:tag] || image[:image][:pull]
        d.update(contents)
        d.update(image[:args].to_s)
      end
      digest.hexdigest!
    end

    def build
      # todo check availability for each image
      name = @docker.generate_build_name("#{@container_config.name}-%{rand}")
      lock = {}
      begin
        do_build name, lock
      rescue
        do_clean lock
        raise
      end
    end

    def needs_build?(lock)
      return true if lock.nil?
      has_images = (lock[:images] || []).each do |image|
        break false unless @docker.has_image?(image[:image])
      end
      !has_images || (build_hash != lock[:hash])
    end

    private

    def do_build(build_name, lock={})
      lock[:hash] ||= build_hash
      lock[:images] = []

      @container_config.images.inject(nil) do |previous, image|
        name = "#{build_name}:#{image[:name]}"
        rc = if image[:image][:pull]
          rc = @docker.has_image?(image[:image][:pull]) ? 0 : docker.pull(image[:image][:pull])
          rc == 0 ? @docker.tag(image[:image][:pull], name) : rc
        elsif image[:image][:tag]
          name = "#{build_name}:#{image[:image][:tag]}"
          @docker.tag(previous, name)
        else
          contents = image[:image][:contents]
          contents = override_from(contents, previous)
          @docker.build(name, contents, image[:args])
        end
        raise StandardError.new("docker build failed, rc=#{rc}") if rc != 0
        lock[:images] << {label: image[:name], image: name}
        name
      end
      lock
    end

    def override_from(contents, previous=nil)
      if previous
        r = contents.sub(/^\s*FROM\s+.+$/i, 'FROM ' + previous)
        r == contents ? "FROM #{previous}\n#{contents}" : r
      else
        contents.match(/^\s*FROM\s+.+$/i) ? contents : "FROM scratch\n#{contents}"
      end
    end

    def do_clean(lock)
      return unless lock
      images = (lock[:images] || []).reverse.inject([]) do |images, image|
        images << name + ':' + image[:label]
      end
      @docker.remove(*images) unless images.empty?
    end

  end
end