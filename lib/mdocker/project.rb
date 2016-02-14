module MDocker
  class Project

    attr_reader :hash, :home_directory, :working_directory, :hostname, :images, :name, :ports

    def initialize(config, hash_path, base_paths)
      @hash_path = hash_path
      @hash = File.readable?(hash_path) ? File.read(hash_path) : nil
      if File.readable? hash_path
        @hash_mtime = File.mtime hash_path
      else
        @hash_mtime = Time.new
      end

      @hostname = config['hostname']
      @name = config['project']
      @working_directory = config['working_directory']
      @home_directory = config['home_directory']
      @ports = config['ports']

      @images = load_project(config, base_paths)
      @mtime = compute_mtime(config)
    end

    def load_project(config, base_paths)
      images = []
      config['images'].each { |image_name, image_config|
        images.push DockerImage.new image_name, image_config, base_paths
      }
      images
    end

    def compute_mtime(config)
      mtimes = @images.map {|image| image.mtime}
      mtimes.push config['mtime']
      mtimes.max
    end

    def update_hash(new_hash)
      @hash = new_hash
      File.open(@hash_path, 'w') { |file| file.write(new_hash) }
      @hash_mtime = File.mtime @hash_path
    end

    def outdated?
      @mtime > @hash_mtime
    end

    def validate
      @name.nil? or raise 'project name is undefined'
      @hostname.nil? or raise 'hostname is undefined'
      # @base_image_name.nil? or raise 'base image (from) is undefined'

      @images.each { |image| image.validate }
      names = @images.map { |image| image.name }
      duplicate = names.detect { |name| names.count(name) > 1 }
      !duplicate.nil? or raise "duplicate docker image name '#{name}'"
    end
  end
end