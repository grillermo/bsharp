# frozen_string_literal: true

# The version lives in SwiftApp/project.yml (xcodegen's source of truth); the
# generated .xcodeproj is gitignored, so this is the only place to bump.
module Versioning
  MARKETING = /^(\s*MARKETING_VERSION:\s*)([\d.]+)\s*$/
  BUILD     = /^(\s*CURRENT_PROJECT_VERSION:\s*)(\d+)\s*$/

  module_function

  def read(text)
    marketing = text[MARKETING, 2] or raise ArgumentError, "no MARKETING_VERSION in project.yml"
    build     = text[BUILD, 2]     or raise ArgumentError, "no CURRENT_PROJECT_VERSION in project.yml"
    { marketing: marketing, build: build.to_i }
  end

  def bump(current, arg)
    return arg if arg =~ /\A\d+\.\d+(\.\d+)?\z/

    major, minor, patch = current.split(".").map(&:to_i)
    patch ||= 0
    case arg
    when "major" then "#{major + 1}.0.0"
    when "minor" then "#{major}.#{minor + 1}.0"
    when "patch", nil then "#{major}.#{minor}.#{patch + 1}"
    else raise ArgumentError, "bad argument '#{arg}' (use patch|minor|major or an X.Y[.Z] version)"
    end
  end

  def write(text, version:, build:)
    text.sub(MARKETING) { "#{$1}#{version}" }.sub(BUILD) { "#{$1}#{build}" }
  end
end
