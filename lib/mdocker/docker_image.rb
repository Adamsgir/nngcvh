module MDocker
  class DockerImage
    attr_accessor :mtime, :build_args, :build_data, :name, :path

    def initialize(name, config, base_paths)
      @build_args = config['args']
      @name = name

      path = config['path']
      @path = path
      docker_file = nil
      base_paths.each do |base_path|
        docker_file = path.start_with?('/') ? path : base_path + File::SEPARATOR + path
        if File.directory? docker_file
          docker_file += File::SEPARATOR + 'Dockerfile'
        end
        if File.readable? docker_file
          break
        end
        docker_file = nil
      end

      @mtime = Time.new 0
      unless docker_file.nil?
        @build_data = File.read(docker_file)
        @mtime = File.mtime docker_file
      end
    end

    def validate
      @path.nil? or raise "undefined path for '#{@name}'"
    end

  end
end