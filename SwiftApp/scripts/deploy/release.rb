# frozen_string_literal: true

# The release bookkeeping ./deploy does around the build: tag names, the
# release notes shown on the install page, the release commit, and deciding
# whether a push worked. Pure functions, so release_test.rb covers them.
module Release
  TAG_PREFIX = "elisa-musica-ota-v"

  # Commit subjects that say nothing to someone installing the app.
  NOTE_NOISE = /\A(Release |Merge |Bump |wip\b)/i
  MAX_NOTES = 8

  module_function

  def tag(version) = "#{TAG_PREFIX}#{version}"

  def tags_for(version) = [tag(version)]

  def tag_patterns = ["#{TAG_PREFIX}*"]

  def commit_message(tag) = "Release ElisaMusica OTA #{tag}"

  # Removes every "--flag value" / "--flag=value" for the given names from
  # argv and returns the values, so the version argument stays positional
  # wherever it sits.
  def take_option(argv, *names)
    values = []
    i = 0
    while i < argv.length
      arg = argv[i]
      if names.include?(arg)
        value = argv[i + 1]
        raise ArgumentError, "#{arg} needs a value" if value.nil? || value.start_with?("--")

        values << value
        argv.slice!(i, 2)
      elsif (eq = arg.match(/\A(--[a-z-]+)=(.*)\z/m)) && names.include?(eq[1])
        values << eq[2]
        argv.slice!(i, 1)
      else
        i += 1
      end
    end
    values
  end

  # --note values may hold several lines or arrive already bulleted.
  def parse_notes(raw)
    raw.flat_map { |n| n.split("\n") }.map { |n| n.strip.sub(/\A[-*•]\s*/, "") }.reject(&:empty?)
  end

  def filter_subjects(subjects)
    subjects.map(&:strip).reject { |s| s.empty? || s.match?(NOTE_NOISE) }.uniq.first(MAX_NOTES)
  end

  def description(version:, summary:, bullets:)
    headline = summary || (bullets.empty? ? "Release #{version}." : "What's new in #{version}:")
    lines = [headline]
    lines << "" unless bullets.empty?
    lines.concat(bullets.map { |b| "• #{b}" })
    lines.join("\n")
  end

  # `git push` can exit non-zero after the remote already took our commit
  # (git-sync pushed first, a flaky connection dropped the reply). If the
  # remote branch is at our HEAD, the release is out.
  def push_outcome(push_ok:, local:, remote:)
    return :pushed if push_ok
    return :already_on_remote if !local.empty? && local == remote

    :failed
  end
end
