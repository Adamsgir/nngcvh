module MDocker
  class Project

    def initialize(project_config, lock_path)
      @project_config = project_config
      @lock_path = lock_path
    end

    def run
      command = @project_config.command
      build
      name, container_config = @project_config.containers.to_a.last
      lock = read_lock
      image = lock[:containers][name][:images].last[:image]
      create_docker.run(image, container_config, command)
    end

    def inspect(container_name=nil)
      @project_config.containers do |name, container_config|
        if container_name.nil? || container_name == name
          puts name
          puts container_config.to_s
        end
      end
    end

    def build
      lock = read_lock
      lock[:containers] ||= {}

      new_lock = {containers: {}}
      begin
        @project_config.containers do |name, container_config|
          container = create_container(container_config)
          container_lock = lock[:containers][name.to_sym]
          if container.needs_build?(container_lock)
            new_lock[:containers][name.to_sym] = container.build
          else
            # was built
            new_lock[:containers][name.to_sym] = lock[:containers].delete(name.to_sym)
          end
        end
        if new_lock != lock
          write_lock new_lock
          do_clean lock
        end
      rescue
        do_clean new_lock
        raise
      end
    end

    def clean
      lock = read_lock
      do_clean lock
      delete_lock
    end

    private

    def create_container(container_config)
      MDocker::Container.new(
          container_config,
          docker: create_docker)
    end

    def do_clean(lock)
      lock ||= read_lock
      image_names = []
      (lock[:containers] || {}).reverse_each do |_, container_lock|
        (container_lock[:images] || []).reverse_each do |image|
          image_names << image[:image]
        end
      end
      create_docker.remove(*image_names) unless image_names.empty?
    end

    def read_lock
      begin
        YAML::load_file(@lock_path)
      rescue SystemCallError, IOError
        {}
      end
    end

    def delete_lock
      begin
        FileUtils::rm_f @lock_path
      rescue SystemCallError, IOError
        # ignored
      end
    end

    def write_lock(lock)
      FileUtils::mkdir_p(File.dirname(@lock_path))
      Dir::Tmpname::create('lock', File.dirname(@lock_path)) do |tmp_path|
        File.open(tmp_path, File::WRONLY|File::CREAT|File::EXCL) do |file|
          file.write YAML::dump(lock)
        end
        FileUtils::mv(tmp_path, @lock_path)
      end
      lock
    end

    def create_docker
      MDocker::Docker.new @project_config.docker_path
    end


  end
end