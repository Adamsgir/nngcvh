module MDocker
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
end
