class ::Hash
  # noinspection RubyScope
  def deep_merge(second)
    merger = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

module MDocker

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

  class Base

    def look_up(base_path, file_name)
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

    def run(path, docker_path, command)
      path = File.expand_path path
      looked_up_path = look_up(path, 'mdocker.yml')
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
              'path' => File.join(Gem.datadir('mdocker'), 'user.dockerfile'),
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
end