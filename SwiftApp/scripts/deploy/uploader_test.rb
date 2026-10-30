# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "uploader"

class UploaderTest < Minitest::Test
  def setup
    @saved = ENV.to_h.slice("ELISA_MUSICA_UPLOAD_BASE", "ELISA_MUSICA_PUBLISH_DIR")
    @dir = Dir.mktmpdir
    @src = Dir.mktmpdir
    ENV["ELISA_MUSICA_UPLOAD_BASE"] = "https://files.example.com/"
    ENV["ELISA_MUSICA_PUBLISH_DIR"] = @dir
  end

  def teardown
    %w[ELISA_MUSICA_UPLOAD_BASE ELISA_MUSICA_PUBLISH_DIR].each { |k| ENV.delete(k) }
    ENV.update(@saved)
    FileUtils.remove_entry(@dir)
    FileUtils.remove_entry(@src)
  end

  def test_base_url_strips_trailing_slashes
    assert_equal "https://files.example.com", Uploader.base_url
  end

  def test_base_url_is_required
    ENV["ELISA_MUSICA_UPLOAD_BASE"] = ""
    assert_raises(SystemExit) { capture_io { Uploader.base_url } }
  end

  def test_upload_replaces_the_target_and_leaves_no_staging_file
    File.write(File.join(@dir, "app-install.html"), "old")
    src = File.join(@src, "page.html")
    File.write(src, "new")

    url = Uploader.upload(src, name: "app-install.html")

    assert_equal "https://files.example.com/files/app-install.html", url
    assert_equal "new", File.read(File.join(@dir, "app-install.html"))
    assert_equal ["app-install.html"], Dir.children(@dir)
  end

  def test_upload_rejects_names_with_directories
    src = File.join(@src, "x")
    File.write(src, "x")
    assert_raises(SystemExit) { capture_io { Uploader.upload(src, name: "../x") } }
  end

  def test_check_publish_dir_dies_when_missing
    ENV["ELISA_MUSICA_PUBLISH_DIR"] = File.join(@dir, "nope")
    assert_raises(SystemExit) { capture_io { Uploader.check_publish_dir! } }
  end
end
