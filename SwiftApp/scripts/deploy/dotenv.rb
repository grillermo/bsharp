# frozen_string_literal: true

# A minimal .env loader, so ./deploy needs no gems. The repo's .env is shared
# with ./serve (the Go server's secrets); ./deploy only uses its
# ELISA_MUSICA_* keys. A variable already set in the environment always
# wins, even when empty, so a one-off `ELISA_MUSICA_PUBLISH_DIR=/tmp/x ./deploy`
# works without editing .env.
module Dotenv
  KEY = /\A[A-Za-z_][A-Za-z0-9_]*\z/

  module_function

  def parse(text)
    text.each_line.with_object({}) do |line, vars|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      key, value = line.sub(/\Aexport\s+/, "").split("=", 2)
      next unless key && value

      key = key.strip
      next unless key.match?(KEY)

      value = value.strip
      if value.length >= 2 && value[0] == value[-1] && ['"', "'"].include?(value[0])
        value = value[1..-2]
      end
      vars[key] = value
    end
  end

  def load(path, env = ENV)
    return unless File.file?(path)

    parse(File.read(path)).each { |key, value| env[key] = value unless env.key?(key) }
  end
end
