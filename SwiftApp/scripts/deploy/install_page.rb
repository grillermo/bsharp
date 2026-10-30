# frozen_string_literal: true

# The install page ./deploy publishes as elisa-musica-install.html. Its URL
# never changes (files.chiq.me/files/elisa-musica-install.html), so a Home Screen
# bookmark always installs the newest release. One self-contained file: no
# external CSS or fonts, because it is opened on a phone, often on cellular.
module InstallPage
  module_function

  def h(str)
    str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;").gsub("'", "&#39;")
  end

  def render(version:, build:, icon_url:, itms_url:, notes:)
    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <title>Install Elisa aprende música</title>
      <style>
        :root { color-scheme: dark; }
        body { margin: 0; padding: 2.5rem 1.25rem 4rem; background: #1b1916; color: #f3ece2;
          font: 16px/1.55 -apple-system, system-ui, sans-serif; display: flex; flex-direction: column; align-items: center; }
        main { width: 100%; max-width: 26rem; }
        img.icon { width: 88px; height: 88px; border-radius: 20px; display: block; margin: 0 auto 1.25rem; }
        h1 { font-family: ui-serif, Georgia, serif; font-weight: 500; font-size: 1.8rem; margin: 0 0 .25rem; text-align: center; }
        .version { text-align: center; color: #a39a90; margin: 0 0 2rem; font-size: .95rem; }
        a.install { display: block; background: #c66a47; color: #fff; text-decoration: none; font-weight: 600;
          font-size: 1.05rem; text-align: center; padding: 1rem; border-radius: 14px; margin-bottom: 1.5rem; }
        a.install:active { background: #a85636; }
        a { color: #e08b68; }
        section { border-top: 1px solid #34302b; padding-top: 1.25rem; margin-top: 1.25rem; }
        h2 { font-size: .8rem; text-transform: uppercase; letter-spacing: .08em; color: #a39a90; margin: 0 0 .6rem; }
        pre.notes { white-space: pre-wrap; margin: 0; font: inherit; color: #e6ddd2; }
        p { color: #c4bbb0; font-size: .9rem; }
        code { background: #2a2622; padding: .15em .4em; border-radius: 5px; font-size: .85em; }
      </style>
      </head>
      <body>
      <main>
        <img class="icon" src="#{h(icon_url)}" alt="">
        <h1>Elisa aprende música</h1>
        <p class="version">Version #{h(version)} (build #{h(build)})</p>
        <a class="install" href="#{h(itms_url)}">Install Elisa aprende música</a>
        <p>Open this page in <strong>Safari</strong>; other browsers cannot start an install.
        Confirm the prompt; the app appears on the Home Screen as <em>Elisa música</em>.</p>
        <section><h2>What&rsquo;s new</h2><pre class="notes">#{h(notes)}</pre></section>
        <section><h2>Updating later</h2>
        <p>Add this page to your Home Screen (Share &rarr; Add to Home Screen). The Install button
        always installs the newest release. Inside the app, touch and hold its icon and choose
        <em>Install Latest</em> for the same thing.</p></section>
        <section><h2>Requirements</h2>
        <p>The iPad or iPhone must be registered on the developer account before the build is made. A device
        added afterwards needs a fresh <code>./deploy</code> before it can install.</p></section>
      </main>
      </body>
      </html>
    HTML
  end
end
