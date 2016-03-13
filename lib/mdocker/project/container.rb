require 'digest/sha1'
require 'yaml'

module MDocker
  class Container

    attr_reader :container_config

    def initialize(container_config, docker:, repository:)
      @container_config = container_config
      @repository = repository
      @docker = docker
    end

    def build_hash
      digest = Digest::SHA1.new
      digest.update(@container_config.name)
      digest = @container_config.images.inject(digest) do |d, image|
        d.update(image[:name])
        if image[:image][:tag] || image[:image][:pull]
          d.update(image[:image][:tag] || image[:image][:pull])
        else
          d.update(image_context_hash(image))
        end
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
      return true unless has_images
      lock[:hash] != build_hash
    end

    private

    def image_context_hash(image)
      object = @repository.object(image[:image])
      d = Digest::SHA1.new
      raise StandardError.new("unknown image location: '#{image[:image].to_yaml}'") unless object
      object.open do |stream|
        TarUtil::untar(src: stream) do |entry:|
          d.update(entry.full_name)
          if entry.file? && entry.size > 0
            while (data = entry.read(256))
              d.update(data)
            end
          end
        end
      end
      d.hexdigest!
    end

    def build_context(image, previous:nil, target:)
      object = @repository.object(image[:image])
      raise StandardError.new("unknown image location: '#{image[:image].to_yaml}'") unless object
      object.open do |stream|
        TarUtil::filter(src: stream, dst: target) do |entry:|
          if 'Dockerfile' == entry.full_name
            DockerFile.new(contents: entry.read).with_from(previous)
          else
            nil
          end
        end
      end
    end

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
          context_provider = Proc.new do |out|
            build_context(image, previous: previous, target:out)
          end
          @docker.build(name, context_provider, image[:args])
        end
        raise StandardError.new("docker build failed, rc=#{rc}") if rc != 0
        lock[:images] << {label: image[:name], image: name}
        name
      end
      lock
    end

    def do_clean(lock)
      return unless lock
      images = (lock[:images] || []).reverse.inject([]) do |images, image|
        images << image[:image]
      end
      @docker.remove(*images) unless images.empty?
    end

  end
end