require 'open3'

module MDocker

  class Util

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

    def self.user_info
      user_name = Etc.getlogin
      user_info = Etc.getpwnam user_name
      {
          name: user_name,
          group: user_name,
          uid: user_info.uid,
          gid: user_info.gid,
          home: Dir.home
      }
    end

    # noinspection RubyScope
    def self.deep_merge(first, second, merge_arrays=false)
      merger = proc { |_, v1, v2|
        if Hash === v1 && Hash === v2
          v1.merge(v2, &merger)
        elsif merge_arrays && Array === v1 && Array == v2
          v1 + v2
        else
          v2
        end
      }
      first.merge(second, &merger)
    end

    def self.symbolize_keys(obj, deep=false)
      case obj
        when Hash
          Hash[obj.map { |k,v| [k.respond_to?(:to_sym) ? k.to_sym : k, deep ? symbolize_keys(v, deep) : v ] }]
        when Array
          obj.map { |item| deep ? symbolize_keys(item, deep) : item }
        else
          obj
      end
    end

    def self.random_string(length=8)
      rand(36**length).to_s(36)
    end

    def self.datadir
      File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data', 'mdocker'))
    end

  end

end
