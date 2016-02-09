require 'yaml'
require 'shellwords'
require 'open3'
require 'etc'

class ::Hash
  # noinspection RubyScope
  def deep_merge(second)
    merger = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

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

  class Docker
    def initialize(command, docker_path='docker')
      @docker_path = docker_path
      @command = command
    end

    def run(project)
      if project.outdated? || !has_image?(project.hash)
        build project
        run project
      else
        port_mappings = ''
        unless project.ports.nil?
          project.ports.each { |port_mapping|
            port_mappings += " -p #{port_mapping}"
          }
        end
        command =
            "#{@docker_path} run --rm -ti" +
            " -h #{Shellwords.escape project.hostname }" +
            " -v #{Shellwords.escape project.home_directory }:#{Shellwords.escape project.home_directory}" +
            " -w #{Shellwords.escape project.working_directory}" +
            port_mappings +
            " #{project.hash}" +
            " #{@command.map { |c| Shellwords.escape c }.join(' ')}"
        puts command
        system(command)
      end
    end

    def build(project)
      project_name = project.name + '-' + rand(36**8).to_s(36)
      begin
        # build images, tag with hash
        base_image_name = nil
        project.images.each { |image|
          if base_image_name.nil?
            build_file = image.build_data
            if build_file.nil?
              base_image_name = image.path
              unless has_image? base_image_name
                rc = MDocker.run_command("#{@docker_path} pull #{base_image_name}", nil, false)
                if rc != 0
                  raise "failed to pull image '#{base_image_name}'"
                end
              end
              next
            end
          else
            if image.build_data.nil?
              raise "Dockerfile not found for '#{image.name}'"
            end
            build_file = image.build_data.sub(/^(FROM\s.+)$/, 'FROM ' + base_image_name)
          end

          build_args = []
          unless image.build_args.nil?
            image.build_args.each { |k,v|
              build_args.push ("--build-arg #{Shellwords.escape(k)}=#{Shellwords.escape(v)} ")
            }
          end
          label = project_name + ':' + image.name
          rc = MDocker.run_command("#{@docker_path} build --force-rm=true -t #{label} #{build_args.join(' ')}-", build_file, false)
          if rc != 0
            raise "build for '#{image.name}' failed"
          end
          base_image_name = label
        }
        old_project_name = nil
        unless project.hash.nil?
          /^(?<old_project_name>[^:]+):.+$/ =~ project.hash
        end
        project.update_hash(base_image_name)
        remove_image(old_project_name)
      rescue
        remove_image(project_name)
        raise
      end
    end

    def has_image?(hash)
      if hash.nil?
        false
      else
        MDocker.run_command("#{@docker_path} inspect #{hash}", nil, true) == 0
      end
    end

    def remove_image(project_name)
      unless project_name.nil?
        MDocker.run_command("#{@docker_path} images --format \"{{.Repository}}:{{.Tag}}\" #{project_name}", nil, true) do |ol, _|
          MDocker.run_command("#{@docker_path} rmi #{ol}", nil, false)
        end
      end
    end
  end

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

  def self.run_command(command, input, mute)
    Open3.popen3(command) do |stdin, stdout, stderr, thread|
      unless input.nil?
        stdin.puts input
        stdin.close
      end
      gobblers = []
      {:out => stdout, :err => stderr }.each do |key, stream|
        gobblers.push (Thread.new do
          until (raw_line = stream.gets).nil? do
            if key == :out
              unless mute
                puts raw_line
              end
              yield raw_line, nil if block_given?
            else
              unless mute
                STDERR.puts raw_line
              end
              yield nil, raw_line if block_given?
            end
          end
        end)
      end
      thread.join
      gobblers.each do |gobbler| gobbler.join end
      thread.value.exitstatus
    end
  end

  def self.look_up(base_path, file_name)
    if File.readable? base_path + File::SEPARATOR + file_name
      base_path
    else
      if base_path == '/' or base_path == ''
        nil
      else
        look_up(File.dirname(base_path), file_name)
      end
    end
  end

  def self.run(path, docker_path, command)
    path = File.expand_path path
    looked_up_path = MDocker.look_up(path, 'mdocker.yml')
    if looked_up_path.nil?
      raise "cannot locate 'mdocker.yml' file up the hierarchy"
    end
    yaml_path = looked_up_path + File::SEPARATOR + 'mdocker.yml'
    hash_path = looked_up_path + File::SEPARATOR + '.mdocker.uid'

    script_file = File.expand_path __FILE__
    script_dir = File.dirname script_file

    config = YAML.load_file yaml_path
    config['mtime'] = [File.mtime(yaml_path), File.mtime(script_file)].max
    config['home_directory'] = Dir.home
    config['working_directory'] = path

    user_name = Etc.getlogin
    user_info = Etc.getpwnam user_name
    # noinspection RubyStringKeysInHashInspection
    user_config = { 'images' => {
        'latest' => {
          'path' => script_dir + File::SEPARATOR + 'mdocker.user.dockerfile',
          'args' => {
              'HOME_DIR' => Dir.home,
              'GID' => user_info.gid,
              'UID' => user_info.uid,
              'USER' => user_name
          }
        }
      }
    }
    config = config.deep_merge user_config

    base_paths = [File.expand_path(looked_up_path + File::SEPARATOR + '.mdocker')]
    unless ENV['MDOCKER_REPO'].nil?
      base_paths.push File.expand_path ENV['MDOCKER_REPO']
    end
    base_paths.push script_dir

    project = Project.new(config, hash_path, base_paths)
    docker = Docker.new(command, docker_path)

    docker.run(project)
  end

end