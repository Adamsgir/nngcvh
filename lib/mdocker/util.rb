require 'open3'

module MDocker

  class Util

    def self.run_command(command, input, mute)
      Open3.popen3(command) do |stdin, stdout, stderr, thread|
        unless input.nil?
          if String === input
            stdin.puts input
          elsif IO === input
            IO::copy_stream(input, stdin)
          elsif Proc === input
            input.call(stdin)
          end
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
      group_info = Etc.getgrgid(user_info.gid)
      {
          name: user_name,
          group: group_info.name,
          uid: user_info.uid,
          gid: user_info.gid,
      }
    end

    def self.deep_merge(first, second, key:[], array_merge: lambda {|_, a1, a2| a1 + a2})
      first.merge(second) do |label,v1,v2|
        if Hash === v1 && Hash === v2
          deep_merge(v1, v2, key: key + [label], array_merge: array_merge)
        elsif array_merge && Array === v1 && Array === v2
          array_merge.call(key + [label], v1, v2)
        else
          v2
        end
      end
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

    def self.assert_type(*expected, value:value)
      match = expected.find { |t| t === value}
      raise StandardError.new "value of '#{expected.join(' ')}' type#{expected.size > 1 ? 's' : ''} " +
                                  "expected, but value of '#{value.class}' type found:\n#{value.to_yaml}" unless match
    end

    def self.dockerfiles_dir
      File.expand_path(File.join(data_dir, 'dockerfiles'))
    end

    def self.data_dir
      File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data'))
    end

  end

end
