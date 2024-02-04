# frozen_string_literal: true

namespace :gh_pages do
  task compile: :environment do
    ENV['GH-PAGES'] = '1'
    ENV['GH-DEPLOY-HOST'] = 'osuc.dev.com'

    sprockets = Sprockets::Environment.new(Rails.root) do |env|
      env.append_path 'app/assets/stylesheets/'
      env.append_path 'app/javascript/packs/'
      env.css_compressor = :sass
      env.js_compressor = Uglifier.new(harmony: true)
    end

    # CSS
    gh_css = sprockets['application.css'].to_s
    # JS
    gh_js = sprockets['schedule.js'].to_s
    # HTML
    renderer = ApplicationController.renderer.new http_host: ENV['GH-DEPLOY-HOST'], https: true
    gh_html_body = renderer.render template: 'schedule/show', layout: false, assigns: { courses: [] }
    # app/templates/gh-pages.html.erb
    html_template = ErbTemplate.new('gh-pages.html')

    # Git
    dir = Dir.mktmpdir
    `git worktree add ../#{dir} -B gh-pages-temp --force`
    Dir.chdir("../#{dir}") do
      `git rm . -r; git branch -D gh-pages; git checkout --orphan gh-pages -q`
      IO.write('index.html', html_template.render(binding)) # gh_html_body, gh_css y gh_js son usados
      `git add -A; git commit -m 'update'`
    end
    `git worktree remove ../#{dir}; git branch -D gh-pages-temp`

    # Se verifica que todo este bien
    print "compiled to branch gh-pages\n#{`git ls-tree gh-pages`}\n"
    print "On branch #{`git branch --show-current`}\nUse git push origin gh-pages -f to update the page\n"
  end
end
