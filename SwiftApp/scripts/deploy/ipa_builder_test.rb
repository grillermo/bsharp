# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "ipa_builder"

class IpaBuilderTest < Minitest::Test
  def test_xcconfig_value_prefers_the_first_file_with_a_value
    Dir.mktmpdir do |dir|
      local = File.join(dir, "Local.xcconfig")
      shared = File.join(dir, "Shared.xcconfig")
      File.write(local, "// DEVELOPMENT_TEAM = COMMENTED\nDEVELOPMENT_TEAM = LOCAL123\n")
      File.write(shared, "DEVELOPMENT_TEAM =\nELISA_MUSICA_BUNDLE_ID = com.example.x\n")

      assert_equal "LOCAL123", IpaBuilder.xcconfig_value("DEVELOPMENT_TEAM", [local, shared])
      assert_equal "com.example.x", IpaBuilder.xcconfig_value("ELISA_MUSICA_BUNDLE_ID", [local, shared])
      assert_nil IpaBuilder.xcconfig_value("DEVELOPMENT_TEAM", [File.join(dir, "missing"), shared])
    end
  end

  def test_signed_build_settings_carry_team_and_urls
    settings = IpaBuilder.xcodebuild_settings(
      unsigned: false, team: "TEAM123",
      ota_manifest_url: "https://files.example.com/files/elisa-musica-manifest.plist",
      devlog_url: "http://macmini.local:19482/api/devlog"
    )
    assert_equal [
      "DEVELOPMENT_TEAM=TEAM123",
      "ELISA_MUSICA_OTA_MANIFEST_URL=https://files.example.com/files/elisa-musica-manifest.plist",
      "ELISA_MUSICA_DEVLOG_URL=http://macmini.local:19482/api/devlog",
    ], settings
  end

  def test_unsigned_build_settings_turn_signing_off_and_omit_empty_urls
    assert_equal ["CODE_SIGNING_ALLOWED=NO"],
                 IpaBuilder.xcodebuild_settings(unsigned: true, team: nil, ota_manifest_url: nil, devlog_url: nil)
  end

  def test_export_options_are_ad_hoc_unthinned_with_a_manifest
    Dir.mktmpdir do |dir|
      path = IpaBuilder.export_options_plist(
        File.join(dir, "ExportOptions.plist"),
        team: "TEAM123",
        manifest: { app_url: "https://x.test/files/A-1.0.ipa?a=1&b=2", icon_url: "https://x.test/files/icon.png" }
      )
      xml = File.read(path)
      assert_includes xml, "<key>method</key><string>release-testing</string>"
      assert_includes xml, "<key>signingStyle</key><string>automatic</string>"
      assert_includes xml, "<key>teamID</key><string>TEAM123</string>"
      assert_includes xml, "<key>thinning</key><string>&lt;none&gt;</string>"
      assert_includes xml, "<key>appURL</key><string>https://x.test/files/A-1.0.ipa?a=1&amp;b=2</string>"
      assert_includes xml, "<key>displayImageURL</key><string>https://x.test/files/icon.png</string>"
      assert system("plutil", "-lint", "-s", path), "ExportOptions.plist must be a valid plist"
    end
  end

  def test_signing_hint_names_the_three_usual_causes
    hint = IpaBuilder.signing_hint(team: "TEAM123", bundle_id: "me.example.app")
    assert_includes hint, "Xcode -> Settings -> Accounts"
    assert_includes hint, "registered"
    assert_includes hint, "me.example.app"
    assert_includes hint, "the App ID me.example.app exists"
    assert_includes hint, "App ID"
  end

  def test_unsigned_flag_reads_the_env
    saved = ENV["ELISA_MUSICA_UNSIGNED"]
    ENV["ELISA_MUSICA_UNSIGNED"] = "1"
    assert IpaBuilder.unsigned?
    ENV["ELISA_MUSICA_UNSIGNED"] = "0"
    refute IpaBuilder.unsigned?
  ensure
    saved.nil? ? ENV.delete("ELISA_MUSICA_UNSIGNED") : ENV["ELISA_MUSICA_UNSIGNED"] = saved
  end
end
