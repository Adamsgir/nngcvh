require 'git'

module MDocker
  class GitRepositoryProvider < RepositoryProvider

    def initialize(file_name)
      @file_name = file_name
    end

    def applicable?(location)
      super(location) && location.start_with?('file://')
    end

    def fetch_origin_contents(resolved_location)
      parts = resolved_location.split('|')

      url = parts[0]

      ref = parts[1]
      ref = 'HEAD' if ref == ''

      path = parts[2]

      tmpdir = Dir.mktmpdir(%w(mdocker. .git))
      begin
        g = Git::clone(url, tmpdir, {depth: 1, bare: true})
        obj = g.object(ref + ':' + path)
        if obj.nil?
          obj = g.object(ref + ':' + path + '/' + @file_name)
        end
        obj.nil? ? nil : obj.contents
      ensure
        if File.exist? tmpdir
          FileUtils::rm_r tmpdir
        end
      end
    end

  end
end