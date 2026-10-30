# frozen_string_literal: true

require "minitest/autorun"
require_relative "versioning"

class VersioningTest < Minitest::Test
  YML = <<~YML
    settings:
      base:
        DEVELOPMENT_TEAM: Q3WS4MWCW3
        MARKETING_VERSION: 1.4.9
        CURRENT_PROJECT_VERSION: 12
  YML

  def test_read
    assert_equal({ marketing: "1.4.9", build: 12 }, Versioning.read(YML))
  end

  def test_bump_keywords
    assert_equal "1.4.10", Versioning.bump("1.4.9", "patch")
    assert_equal "1.4.10", Versioning.bump("1.4.9", nil)
    assert_equal "1.5.0", Versioning.bump("1.4.9", "minor")
    assert_equal "2.0.0", Versioning.bump("1.4.9", "major")
  end

  def test_bump_explicit
    assert_equal "3.1.0", Versioning.bump("1.4.9", "3.1.0")
    assert_equal "3.1", Versioning.bump("1.4.9", "3.1")
  end

  def test_bump_rejects_junk
    assert_raises(ArgumentError) { Versioning.bump("1.4.9", "banana") }
  end

  def test_write_rewrites_only_the_two_fields
    out = Versioning.write(YML, version: "1.5.0", build: 13)
    assert_equal({ marketing: "1.5.0", build: 13 }, Versioning.read(out))
    assert_includes out, "DEVELOPMENT_TEAM: Q3WS4MWCW3"
  end

  def test_read_raises_without_fields
    assert_raises(ArgumentError) { Versioning.read("name: x\n") }
  end
end
