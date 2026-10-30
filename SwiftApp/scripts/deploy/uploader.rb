# frozen_string_literal: true

# Publishes release artifacts into the files/ directory that the file_server
# service behind files.chiq.me serves (~/c/file_server/files on the macmini).
#
# That service runs on this machine, so a release is a local file copy, not an
# HTTP upload: request bodies past roughly 12 MB stall in the Cloudflare tunnel
# and the edge answers 524 before the origin ever sees them.
#
# Every publish is *pinned*: the artifact lands at exactly the name given and
# replaces what was there. That keeps the manifest and install page URLs fixed,
# so one Home Screen bookmark keeps installing the newest release.

require "fileutils"
require_relative "ipa_builder"

module Uploader
  # file_server is checked out beside this repo and serves its own files/ dir.
  DEFAULT_PUBLISH_DIR = File.expand_path("../file_server/files", IpaBuilder::REPO_ROOT)

  module_function

  # The public URL the published files are served under, from .env.
  def base_url
    base = ENV["ELISA_MUSICA_UPLOAD_BASE"].to_s
    if base.empty?
      IpaBuilder.die("set ELISA_MUSICA_UPLOAD_BASE (in .env) to the file server's public URL, " \
                     "e.g. https://files.chiq.me")
    end
    base.sub(%r{/+\z}, "")
  end

  def publish_dir = ENV.fetch("ELISA_MUSICA_PUBLISH_DIR", DEFAULT_PUBLISH_DIR)

  # ./deploy calls this in preflight, so a missing service fails before a
  # build rather than after one.
  def check_publish_dir!
    dir = publish_dir
    return dir if File.directory?(dir)

    IpaBuilder.die(
      "the file_server files/ directory was not found at #{dir}.\n" \
      "  Releases are published by copying into it. Set ELISA_MUSICA_PUBLISH_DIR if it moved."
    )
  end

  # Publishes `path` under exactly `name` and returns its public URL.
  def upload(path, name:)
    IpaBuilder.die("file to publish not found: #{path}") unless File.file?(path)
    IpaBuilder.die("unsafe publish name: #{name.inspect}") unless name == File.basename(name) && !name.start_with?(".")

    target = File.join(check_publish_dir!, name)
    # Copy beside the target, then rename over it: rename is atomic on one
    # filesystem, so a phone downloading a pinned URL never gets half a file.
    staged = "#{target}.publishing-#{Process.pid}"
    begin
      FileUtils.cp(path, staged)
      File.rename(staged, target)
    ensure
      FileUtils.rm_f(staged)
    end

    "#{base_url}/files/#{name}"
  end
end
