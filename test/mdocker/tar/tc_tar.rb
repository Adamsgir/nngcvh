require_relative '../../test_helper'

module MDocker
  class TarTest < Test::Unit::TestCase

    include MDocker::TestBase

    def create_tar_file(src, dst)
      File::open(dst, 'w') do |io|
        TarUtil::tar(src:src, dst:io)
      end
    end

    def untar_to_dir(src, dst)
      File::open(src, 'r') do |tar_io|
        TarUtil::untar(src:tar_io) do |entry:, writer:|
          full_path = File.join(File.join(dst, entry.full_name))
          if entry.directory?
            FileUtils::mkdir_p(full_path)
          elsif entry.file?
            FileUtils::mkdir_p(File.dirname(full_path))
            File::open(full_path, 'w') { |io| writer.call(entry, io) }
          end
          FileUtils::chmod(entry.header.mode, full_path)
        end
      end
    end

    def test_tar_write
      with_fixture('tar') do |fixture|
        src = fixture.expand_path 'src'
        dst = fixture.expand_path 'dst.tar'
        create_tar_file(src, dst)

        assert_true File.file? dst
        assert_true File.size(dst) > 0
      end
    end

    def test_tar_read
      with_fixture('tar') do |fixture|
        src = fixture.expand_path 'src'
        dst = fixture.expand_path 'dst.tar'
        create_tar_file(src, dst)

        dst_dir = fixture.expand_path 'dst'
        untar_to_dir(dst, dst_dir)

        assert_equal File.read(fixture.expand_path('src/file.txt')),
                     File.read(fixture.expand_path('dst/file.txt'))
        assert_equal File.read(fixture.expand_path('src/dir/file.txt')),
                     File.read(fixture.expand_path('dst/dir/file.txt'))
      end
    end

    def test_tar_filter
      with_fixture('tar') do |fixture|
        src = fixture.expand_path 'src'
        dst = fixture.expand_path 'dst.tar'
        create_tar_file(src, dst)

        filtered = fixture.expand_path('filtered.tar')

        File::open(dst, 'r') do |src_tar_io|
          File::open(filtered, 'w') do |dst_tar_io|
            TarUtil::filter(src:src_tar_io, dst:dst_tar_io) do |entry:, dst:, writer:|
              writer.call(entry, dst)
              entry.rewind
              writer.call(entry, dst)
            end
          end
        end
        filtered_dir = fixture.expand_path 'dst'
        untar_to_dir(filtered, filtered_dir)

        assert_equal File.read(fixture.expand_path('src/file.txt')) * 2,
                     File.read(fixture.expand_path('dst/file.txt'))
        assert_equal File.read(fixture.expand_path('src/dir/file.txt')) * 2,
                     File.read(fixture.expand_path('dst/dir/file.txt'))
      end

    end

    def test_tar_from_hash
      with_fixture('tar') do |fixture|
        out = fixture.expand_path 'out.tar'
        hash = {
            :dir.to_s => {ftype: 'directory'},
            :'dir/file.txt'.to_s => {ftype: 'file', contents: 'dir/file.txt'}
        }
        File::open(out, 'w') do |io|
          TarUtil::tar_from_hash(src:hash, dst:io)
        end

        untar_to_dir(out, fixture.expand_path('dst'))
        assert_equal 'dir/file.txt', File.read(fixture.expand_path('dst/dir/file.txt'))

      end
    end
  end
end