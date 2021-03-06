require 'rack/request'
require 'indexable/phantomjs'

module Indexable
  class Middleware
    PATHS_TO_PRERENDER = [
      /.+print/, /.+benchmarks/
    ]

    def initialize(app)
      @app = app
    end

    # Detect whether the current request comes from a bot. Based on the logic used
    # by Bustle.com (https://www.dropbox.com/s/s4oibqsxqpo3hll/bustle%20slizzle.pdf)
    def request_for_prerendered_path?(env)
      path = env["REQUEST_URI"]
      return true if PATHS_TO_PRERENDER.any? {|s| path.match(s) } 
      # my fork works for all user agents, not just crawlers
      # user_agent  = env["HTTP_USER_AGENT"]
      # params      = Rack::Request.new(env).params
      # return false  unless user_agent
      # return true   if CRAWLER_USER_AGENTS.any? {|s| user_agent.match(s) }
      # return true   if params.has_key?('_escaped_fragment_')
      # params['nojs'].eql?('true')
    end

    def call(env)
      status, headers, content = *@app.call(env)

      if status == 200 and headers['Content-Type'].match(/^text\/html/) and request_for_prerendered_path?(env)
        script = ::File.dirname(__FILE__) + "/render_page.js"
        file = Tempfile.new(['indexable', '.html'])

        if content.respond_to? :body
          html = content.body
        else
          html = content.join('')
        end

        file.write html
        file.close
        begin
          url = Rack::Request.new(env).url
          content = [Phantomjs.new(script, file.path, url).run]
          status = 500 if content[0] == "Couldn't render page... orz."
        ensure
          file.unlink
        end
      end

      [status, headers, content]
    end
  end
end
