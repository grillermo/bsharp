# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "dotenv"

class DotenvTest < Minitest::Test
  def test_parse_reads_key_value_lines
    assert_equal({ "A" => "1", "B" => "two" }, Dotenv.parse("A=1\nB=two\n"))
  end

  def test_parse_skips_comments_blank_lines_and_junk
    text = "# comment\n\n  \nnot a pair\n1BAD=x\nGOOD=yes\n"
    assert_equal({ "GOOD" => "yes" }, Dotenv.parse(text))
  end

  def test_parse_strips_matching_quotes_and_export
    text = %(export Q1="hello world"\nQ2='single'\nQ3="unbalanced'\n)
    assert_equal({ "Q1" => "hello world", "Q2" => "single", "Q3" => %("unbalanced') }, Dotenv.parse(text))
  end

  def test_parse_keeps_equals_signs_in_the_value
    assert_equal({ "URL" => "https://x.test/?a=b&c=d" }, Dotenv.parse("URL=https://x.test/?a=b&c=d\n"))
  end

  def test_load_never_overrides_an_existing_variable
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".env")
      File.write(path, "KEEP=from-file\nNEW=added\nEMPTY=from-file\n")
      env = { "KEEP" => "from-shell", "EMPTY" => "" }
      Dotenv.load(path, env)
      assert_equal({ "KEEP" => "from-shell", "EMPTY" => "", "NEW" => "added" }, env)
    end
  end

  def test_load_ignores_a_missing_file
    env = {}
    Dotenv.load("/nonexistent/.env", env)
    assert_empty env
  end
end
