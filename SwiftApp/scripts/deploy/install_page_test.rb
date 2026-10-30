# frozen_string_literal: true

require "minitest/autorun"
require_relative "install_page"

class InstallPageTest < Minitest::Test
  def page(notes: "What's new in 1.0.4:\n\n• Fix chime")
    InstallPage.render(
      version: "1.0.4", build: 6,
      icon_url: "https://files.example.com/files/elisa-musica-icon.png",
      itms_url: "itms-services://?action=download-manifest&url=https://files.example.com/files/elisa-musica-manifest.plist",
      notes: notes
    )
  end

  def test_install_button_links_to_the_escaped_itms_url
    assert_includes page, 'href="itms-services://?action=download-manifest&amp;url=https://files.example.com/files/elisa-musica-manifest.plist"'
  end

  def test_shows_version_build_icon_and_notes
    html = page
    assert_includes html, "Version 1.0.4 (build 6)"
    assert_includes html, 'src="https://files.example.com/files/elisa-musica-icon.png"'
    assert_includes html, "• Fix chime"
  end

  def test_escapes_everything_inserted
    html = page(notes: %(<script>alert("x")</script> & 'q'))
    refute_includes html, "<script>alert"
    assert_includes html, "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; &#39;q&#39;"
  end

  def test_has_the_required_guidance_and_is_dark
    html = page
    assert_includes html, "color-scheme: dark"
    assert_includes html, "Safari"
    assert_includes html, "Add to Home Screen"
    assert_includes html, "registered"
    assert_includes html, 'name="viewport"'
  end
end
