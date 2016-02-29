require 'shellwords'

module MDocker

  DOCKER_PATH = 'docker'

  class Docker
    def initialize(config, opts={})
      @opts = opts || {}
      @opts[:docker] ||= DOCKER_PATH
      @config = config
    end

    def generate_build_name(project_name)
      name = "#{project_name}-#{MDocker::Util::random_string(8)}"
      while has_image?(name)
        name = "#{project_name}-#{MDocker::Util::random_string(8)}"
      end
      name
    end

    def tag(image_name, label)
      docker('tag', image_name, label)
    end

    def pull(image_name)
      docker('pull', image_name, mute:false)
    end

    def build(image_name, contents, args)
      command_args =  []
      command_args << '--force-rm=true'
      command_args << '-t'
      command_args << image_name
      args.each do |k,v|
        command_args << '--build-arg'
        command_args << "#{k.to_s}=#{v}"
      end
      command_args << '-'
      docker('build', *command_args, input: contents, mute: false)
    end

    def run(image_name)
      command_args =  []
      command_args << '--rm'
      command_args << '-ti'
      command_args << '-h'
      command_args << @config.get(:project, :container, :hostname)
      command_args << '-w'
      command_args << @config.get(:project, :container, :working_directory)
      @config.get(:project, :container, :volumes).each do |volume|
        host, container = volume.first
        command_args << '-v'
        command_args << "#{host.to_s}:#{container}"
      end
      @config.get(:project, :container, :ports).each do |port|
        host, container = port.first
        command_args << '-p'
        command_args << "#{host.to_s}:#{container}"
      end
      command_args << image_name
      command_args += @config.get(:project, :container, :command)
      command = "#{@opts[:docker]} run #{command_args.join(' ')}"
      puts command
      system(command)
    end

    def remove(*image_names)
      command_args = ['-f'] + image_names
      docker('rmi', command_args, mute: false)
    end

    def has_image?(image_name)
      docker('inspect', image_name) == 0
    end

    private

    def docker(command, *args, input:nil, mute:true)
      if block_given?
        MDocker::Util::run_command("#{@opts[:docker]} #{command} #{args.join(' ')}", input, mute) do |ol, el|
          yield ol, el
        end
      else
        MDocker::Util::run_command("#{@opts[:docker]} #{command} #{args.join(' ')}", input, mute)
      end
    end
  end
end