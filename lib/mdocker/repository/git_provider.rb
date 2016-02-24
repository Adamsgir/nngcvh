require 'git'

module MDocker
  class GitRepositoryProvider < RepositoryProvider

    UPDATE_PRICE = 50

    def initialize(file_name, tmp_location=nil)
      super UPDATE_PRICE
      @file_name = file_name
      @tmp_location = tmp_location.nil? ? nil : File.expand_path(tmp_location)
    end

    def applicable?(location)
      super(location) && location[:git]
    end

    def resolve(location)
      {
        git: location[:git],
        ref: location[:ref].to_s.strip.empty? ? 'master' : location[:ref],
        path: location[:path].to_s.strip.empty? ? @file_name : location[:path]
      }
    end

    def fetch_origin_contents(location)
      url = location[:git]
      ref = location[:ref]
      path = location[:path]

      FileUtils::mkdir_p @tmp_location

      begin
        tmpdir = Dir.mktmpdir(%w(mdocker. .git), @tmp_location)
        rc = MDocker::Util::run_command("git clone --branch \"#{ref}\" --bare --depth 1 \"#{url}\" \"#{tmpdir}\"", nil, true)
        if rc != 0
          git = Git::clone(url, tmpdir, {bare: true})
        else
          git = Git::bare(tmpdir)
        end
        obj = git.object(ref + ':' + path)
        if obj.nil? || obj.tree?
          obj = git.object(ref + ':' + path + '/' + @file_name)
        end
        raise "no blob found for #{location}" unless obj.blob?
        obj.contents
      ensure
        if File.exist? tmpdir
          FileUtils::rm_r tmpdir
        end
      end
    end

  end
end