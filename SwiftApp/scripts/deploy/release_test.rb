# frozen_string_literal: true

require "minitest/autorun"
require_relative "release"

class ReleaseTest < Minitest::Test
  def test_tag_uses_the_app_prefix
    assert_equal "elisa-musica-ota-v1.0.4", Release.tag("1.0.4")
  end

  def test_tags_for_is_just_the_tag
    assert_equal %w[elisa-musica-ota-v1.0.3], Release.tags_for("1.0.3")
  end

  def test_tag_patterns
    assert_equal %w[elisa-musica-ota-v*], Release.tag_patterns
  end

  def test_commit_message_is_one_line
    assert_equal "Release ElisaMusica OTA elisa-musica-ota-v1.0.4", Release.commit_message("elisa-musica-ota-v1.0.4")
  end

  def test_take_option_pulls_flag_values_out_of_argv
    argv = ["minor", "--note", "one", "--note=two", "-s", "Headline"]
    assert_equal %w[one two], Release.take_option(argv, "--note", "-n")
    assert_equal ["Headline"], Release.take_option(argv, "--summary", "-s")
    assert_equal ["minor"], argv
  end

  def test_take_option_requires_a_value
    assert_raises(ArgumentError) { Release.take_option(["--note"], "--note") }
    assert_raises(ArgumentError) { Release.take_option(["--note", "--yes"], "--note") }
  end

  def test_parse_notes_splits_lines_and_strips_bullets
    assert_equal %w[one two three], Release.parse_notes(["- one\n* two", "   ", "• three"])
  end

  def test_filter_subjects_drops_noise_and_caps_at_eight
    subjects = [
      "Release ElisaMusica OTA elisa-musica-ota-v1.0.3", "Merge branch 'x'", "Bump deps", "wip: half done", "WIP",
      "", "Fix chime", "Fix chime",
      *(1..9).map { |i| "Change #{i}" }
    ].map { |s| "#{s}\n" }
    assert_equal ["Fix chime", *(1..7).map { |i| "Change #{i}" }], Release.filter_subjects(subjects)
  end

  def test_description_with_summary_and_bullets
    assert_equal "Faster\n\n• a\n• b", Release.description(version: "1.0.4", summary: "Faster", bullets: %w[a b])
  end

  def test_description_without_summary
    assert_equal "What's new in 1.0.4:\n\n• a", Release.description(version: "1.0.4", summary: nil, bullets: ["a"])
    assert_equal "Release 1.0.4.", Release.description(version: "1.0.4", summary: nil, bullets: [])
  end

  def test_push_outcome
    assert_equal :pushed, Release.push_outcome(push_ok: true, local: "abc", remote: "")
    assert_equal :already_on_remote, Release.push_outcome(push_ok: false, local: "abc", remote: "abc")
    assert_equal :failed, Release.push_outcome(push_ok: false, local: "abc", remote: "def")
    assert_equal :failed, Release.push_outcome(push_ok: false, local: "", remote: "")
  end
end
