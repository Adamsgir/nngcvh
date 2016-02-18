require 'git'

module MDocker
  class GitRepositoryProvider < RepositoryProvider

    def initialize(file_name, tmp_location=nil)
      @file_name = file_name
      @tmp_location = tmp_location.nil? ? nil : File.expand_path(tmp_location)
    end

    def applicable?(location)
      super(location) && location.start_with?('file://')
    end

    def fetch_origin_contents(resolved_location)
      parts = resolved_location.split('|')

      url = parts[0]

      ref = parts[1]
      ref = 'HEAD' if ref == '' || ref.nil?

      path = parts[2]
      path = '' if parts[2].nil?

      unless File.directory? @tmp_location
        FileUtils::mkdir_p @tmp_location
      end

      tmpdir = Dir.mktmpdir(%w(mdocker. .git), @tmp_location)
      begin
        git = Git::clone(url, tmpdir, {depth: 1, bare: true})
        obj = git.object(ref + ':' + path)
        if obj.nil? || obj.tree?
          obj = git.object(ref + ':' + (path == '' ? '' : path + '/') + @file_name)
        end
        obj.blob? ? obj.contents : nil
      ensure
        if File.exist? tmpdir
          FileUtils::rm_r tmpdir
        end
      end
    end

  end
end