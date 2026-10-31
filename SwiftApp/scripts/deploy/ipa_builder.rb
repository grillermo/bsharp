# frozen_string_literal: true

# Builds an ad-hoc-signed ElisaMusica .ipa from SwiftApp/project.yml, together with the OTA
# manifest.plist an `itms-services://` link points at. Used by ../../deploy.
#
# Signed for the team in SwiftApp/Config/Local.xcconfig, it installs from Safari with no
# cable, but only on devices registered on the developer portal before the build, and only
# once the App ID <ELISA_MUSICA_BUNDLE_ID> exists there (automatic signing creates
# certificates and profiles, never App IDs).
#
# ELISA_MUSICA_UNSIGNED=1 falls back to an unsigned Payload/ zip, which
# cannot install from Safari; it exists so a broken signing setup never blocks
# getting a binary.

require "fileutils"
require "shellwords"
require "tmpdir"

module IpaBuilder
  APP_NAME    = "ElisaMusica"
  SCHEME      = "ElisaMusica"
  # The app lives in SwiftApp/ of the bsharp repo (the root is the web app). Git commands run
  # from REPO_ROOT; xcodegen, xcodebuild and the xcconfigs work in IOS_DIR.
  IOS_DIR     = File.expand_path(File.join(__dir__, "..", ".."))
  REPO_ROOT   = File.dirname(IOS_DIR)
  PROJECT     = "ElisaMusica.xcodeproj"
  PROJECT_YML = File.join(IOS_DIR, "project.yml")
  # Same order Xcode applies them: Local.xcconfig is #included last by the
  # committed file, so its values win.
  XCCONFIGS = [
    File.join(IOS_DIR, "Config", "Local.xcconfig"),
    File.join(IOS_DIR, "Config", "ElisaMusica.xcconfig"),
  ].freeze

  module_function

  def bold(str) = "\e[1m#{str}\e[0m"
  def green(str) = "\e[32m#{str}\e[0m"
  def red(str) = "\e[31m#{str}\e[0m"
  def step(msg) = puts "\n#{bold("==> #{msg}")}"

  def die(msg)
    warn red("error: #{msg}")
    exit 1
  end

  def run(cmd, chdir:, hint: nil)
    puts "    $ #{cmd}"
    system(cmd, chdir: chdir) or die(["command failed: #{cmd}", hint].compact.join("\n"))
  end

  def unsigned? = ENV["ELISA_MUSICA_UNSIGNED"] == "1"

  # A build setting as Xcode resolves it from the xcconfigs: the first file
  # that gives it a non-empty value wins.
  def xcconfig_value(key, paths = XCCONFIGS)
    paths.each do |path|
      next unless File.exist?(path)

      value = File.read(path)[/^\s*#{Regexp.escape(key)}\s*=[ \t]*(\S*)/, 1]
      return value if value && !value.empty?
    end
    nil
  end

  def bundle_id = xcconfig_value("ELISA_MUSICA_BUNDLE_ID")

  # ELISA_MUSICA_TEAM_ID overrides Local.xcconfig for a one-off.
  def team_id
    id = ENV["ELISA_MUSICA_TEAM_ID"] || xcconfig_value("DEVELOPMENT_TEAM")
    die("no DEVELOPMENT_TEAM in SwiftApp/Config/Local.xcconfig and no ELISA_MUSICA_TEAM_ID set (see README)") if id.to_s.empty?
    id
  end

  # xcodebuild needs a full Xcode, not the Command Line Tools. Honour an
  # existing DEVELOPER_DIR, otherwise use the newest /Applications/Xcode*.app.
  def resolve_developer_dir
    env = ENV["DEVELOPER_DIR"]
    return env if env && Dir.exist?(env)

    xcode = Dir.glob("/Applications/Xcode*.app").max
    die("no Xcode.app found; install Xcode or set DEVELOPER_DIR") unless xcode
    File.join(xcode, "Contents", "Developer")
  end

  # Over SSH, or after the Mac slept, the login keychain is locked and codesign
  # cannot use the signing key: the archive then dies at its first CodeSign
  # step (errSecInternalComponent) after minutes of compiling. Probe by signing
  # a throwaway copy of /usr/bin/true; if that fails, unlock the keychain
  # (prompts for the login password) and probe again.
  def ensure_codesign_can_sign!
    return if unsigned?

    probe = File.join(Dir.tmpdir, "#{APP_NAME}-codesign-probe-#{Process.pid}")
    FileUtils.cp("/usr/bin/true", probe)
    sign = "codesign -f -s 'Apple Development' #{Shellwords.escape(probe)} >/dev/null 2>&1"
    return if system(sign)
    # Unattended unlock with the login password stored on this Mac (agents-configs),
    # so an agent can deploy over SSH; the prompt below is the fallback.
    return if system(File.expand_path("~/c/agents-configs/bin/unlock-codesign-keychain.sh"))

    puts red("    codesign cannot use your signing key -- the login keychain is probably locked.")
    keychain = File.expand_path("~/Library/Keychains/login.keychain-db")
    system("security unlock-keychain #{Shellwords.escape(keychain)}") or
      die("could not unlock the login keychain")
    system(sign) or
      die("codesign still fails after unlocking; try: codesign -f -s 'Apple Development' /tmp/somefile")
  ensure
    FileUtils.rm_f(probe) if probe
  end

  def signing_hint(team:, bundle_id:)
    "If this is a signing failure, check:\n" \
      "  - the Apple ID for team #{team} is signed in at Xcode -> Settings -> Accounts;\n" \
      "  - the iPad's / iPhone's UDID is registered on developer.apple.com (ad hoc builds only\n" \
      "    install on devices registered before the build; re-run ./deploy after adding one);\n" \
      "  - the App ID #{bundle_id} exists on the portal\n" \
      "    (automatic signing creates certificates and profiles, but never App IDs)."
  end

  # Build settings passed on the xcodebuild command line. The URLs go here
  # rather than in an xcconfig because xcconfig reads `//` as a comment.
  def xcodebuild_settings(unsigned:, team:, ota_manifest_url:, devlog_url:)
    settings = unsigned ? ["CODE_SIGNING_ALLOWED=NO"] : ["DEVELOPMENT_TEAM=#{Shellwords.escape(team)}"]
    settings << "ELISA_MUSICA_OTA_MANIFEST_URL=#{Shellwords.escape(ota_manifest_url)}" if ota_manifest_url
    settings << "ELISA_MUSICA_DEVLOG_URL=#{Shellwords.escape(devlog_url)}" if devlog_url
    settings
  end

  def xml_escape(str) = str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")

  # `release-testing` is Xcode 15.3+'s name for ad hoc. thinning `<none>`
  # keeps one universal .ipa, because a single download URL cannot serve
  # per-device variants. The `manifest` dict makes xcodebuild write the
  # manifest.plist an itms-services:// link needs, so it can never drift from
  # the binary; appURL must be the .ipa's final public URL, known before the
  # build because the .ipa name carries the version.
  def export_options_plist(path, manifest:, team:)
    File.write(path, <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>method</key><string>release-testing</string>
        <key>teamID</key><string>#{xml_escape(team)}</string>
        <key>signingStyle</key><string>automatic</string>
        <key>stripSwiftSymbols</key><true/>
        <key>thinning</key><string>&lt;none&gt;</string>
        <key>destination</key><string>export</string>
        <key>manifest</key>
        <dict>
          <key>appURL</key><string>#{xml_escape(manifest[:app_url])}</string>
          <key>displayImageURL</key><string>#{xml_escape(manifest[:icon_url])}</string>
          <key>fullSizeImageURL</key><string>#{xml_escape(manifest[:icon_url])}</string>
        </dict>
      </dict>
      </plist>
    PLIST
    path
  end

  # Returns the .ipa path. The caller owns (and removes) File.dirname(ipa);
  # for a signed build manifest.plist is written beside the .ipa there.
  def build(manifest:, ota_manifest_url: nil, devlog_url: nil)
    ENV["DEVELOPER_DIR"] = resolve_developer_dir
    puts "    DEVELOPER_DIR=#{ENV['DEVELOPER_DIR']}"
    team = unsigned? ? nil : team_id
    hint = unsigned? ? nil : signing_hint(team: team, bundle_id: bundle_id)

    step "Generating the Xcode project (xcodegen)"
    run("xcodegen generate", chdir: IOS_DIR)

    work    = Dir.mktmpdir("#{APP_NAME}-ipa-")
    archive = File.join(work, "#{APP_NAME}.xcarchive")
    settings = xcodebuild_settings(unsigned: unsigned?, team: team,
                                   ota_manifest_url: ota_manifest_url, devlog_url: devlog_url)

    step "Archiving (xcodebuild)#{unsigned? ? ' [UNSIGNED]' : ''}"
    run(
      "xcodebuild -project #{PROJECT} -scheme #{SCHEME} -configuration Release " \
      "-destination 'generic/platform=iOS' -archivePath #{Shellwords.escape(archive)} " \
      "#{settings.join(' ')} -allowProvisioningUpdates archive",
      chdir: IOS_DIR, hint: hint
    )
    die("archive not produced: #{archive}") unless Dir.exist?(archive)

    return package_unsigned(archive, work) if unsigned?

    step "Exporting signed .ipa (ad hoc)"
    options = export_options_plist(File.join(work, "ExportOptions.plist"), manifest: manifest, team: team)
    run(
      "xcodebuild -exportArchive -archivePath #{Shellwords.escape(archive)} " \
      "-exportPath #{Shellwords.escape(work)} -exportOptionsPlist #{Shellwords.escape(options)} " \
      "-allowProvisioningUpdates",
      chdir: IOS_DIR, hint: hint
    )

    ipa = File.join(work, "#{APP_NAME}.ipa")
    die("export produced no .ipa in #{work} (see the xcodebuild output above).\n#{hint}") unless File.exist?(ipa)
    ipa
  end

  # Zips the archived .app into Payload/ by hand. ditto --keepParent keeps
  # Payload/ at the zip root and preserves the symlinks inside frameworks,
  # which plain zip can mangle.
  def package_unsigned(archive, work)
    app = File.join(archive, "Products", "Applications", "#{APP_NAME}.app")
    die("no #{APP_NAME}.app inside the archive: #{app}") unless Dir.exist?(app)

    step "Packaging .ipa (unsigned)"
    payload = File.join(work, "Payload")
    FileUtils.mkdir_p(payload)
    FileUtils.cp_r(app, payload)
    ipa = File.join(work, "#{APP_NAME}.ipa")
    run("ditto -c -k --sequesterRsrc --keepParent #{Shellwords.escape(payload)} #{Shellwords.escape(ipa)}",
        chdir: work)
    ipa
  end
end
