# frozen_string_literal: true

require "rake/testtask"
require "bundler/gem_tasks"
require "fileutils"
require "find"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

namespace :docs do
  desc "Fix YARD documentation for subpath hosting"
  task :fix do
    require_relative "lib/rooq/version"
    version = Rooq::VERSION
    base_url = "https://ggalmazor.com/rooq/"
    doc_dir = File.join(__dir__, "doc")

    unless Dir.exist?(doc_dir)
      puts "Error: #{doc_dir} not found. Run 'yard doc' first."
      exit 1
    end

    # 1. Fix app.js (the AJAX navigation issue)
    app_js_path = File.join(doc_dir, "js", "app.js")
    if File.exist?(app_js_path)
      content = File.read(app_js_path)
      search_pattern = /if \(e\.data\.action === "navigate"\) \{/
      if content.match?(search_pattern)
        puts "Applying fix to #{app_js_path}..."

        replacement = <<~'JS'.chomp
          if (e.data.action === "navigate") {
                /*
                  When hosted at a subpath (e.g., https://ggalmazor.com/rooq/),
                  we need to ensure relative URLs from the iframe are resolved
                  against the documentation's root path, not the current browser URL
                  which might have changed due to pushState.
                */
                const indexPage = window.location.pathname.indexOf('/index.html');
                const rootPath = indexPage !== -1
                  ? window.location.pathname.substring(0, indexPage + 1)
                  : window.location.pathname.replace(/\/[^\/]*$/, "/");

                const baseUrl = window.location.origin + rootPath;
                const url = new URL(e.data.url, baseUrl);
        JS

        content.gsub!(search_pattern, replacement)
        content.gsub!("fetch(e.data.url)", "fetch(url.href)")
        content.gsub!('history.pushState({}, document.title, e.data.url)', "history.pushState({}, document.title, url.href)")
        redundant_url_parser = /const url = new URL\(e\.data\.url, "https:\/\/localhost"\);/
        content.gsub!(redundant_url_parser, "")

        File.write(app_js_path, content)
        puts "Fix applied to app.js."
      end
    end

    # 2. Convert all relative links to absolute links in HTML files and inject version
    puts "Converting relative links to absolute and injecting version #{version} in #{doc_dir}..."

    extra_files_mapping = {
      "USAGE_md.html" => "file.USAGE.html",
      "CHANGELOG_md.html" => "file.CHANGELOG.html"
    }

    Find.find(doc_dir) do |path|
      next unless path.end_with?(".html")

      content = File.read(path)

      # Inject version into title if it's the standard "rOOQ Documentation"
      content.gsub!("rOOQ Documentation", "rOOQ v#{version} Documentation")

      # Inject version into the #menu element for better visibility
      content.gsub!(/<div id="menu">/, "<div id=\"menu\">\n  <span class=\"version\">v#{version}</span>")

      # YARD uses relative paths like "", "Rooq", "Rooq/SomeSubClass"
      # We want to find href="../something.html" and replace it with base_url + something.html

      new_content = content.gsub(/(href|src)=["']([^"']+)["']/) do |match|
        attr = ::Regexp.last_match(1)
        url = ::Regexp.last_match(2)

        # If it's an absolute URL starting with our base_url, we might need to fix it
        if url.start_with?(base_url)
          relative_part = url.sub(base_url, "")
          if extra_files_mapping.key?(relative_part)
            "#{attr}=\"#{base_url}#{extra_files_mapping[relative_part]}\""
          else
            match
          end
        # Skip other absolute URLs, anchors, and data URIs
        elsif url.start_with?("http://", "https://", "#", "data:") || url.empty?
          match
        else
          # Fix links to extra files that YARD renames
          target_url = extra_files_mapping[url] || url

          # If it's one of our extra files, it's at the root of doc/
          absolute_file_path = if extra_files_mapping.key?(url)
                                 File.join(File.expand_path(doc_dir), target_url)
                               else
                                 File.expand_path(target_url, File.dirname(path))
                               end

          if absolute_file_path.start_with?(File.expand_path(doc_dir))
            relative_to_doc_root = absolute_file_path.sub("#{File.expand_path(doc_dir)}/", "")
            # Handle index.html at root
            relative_to_doc_root = "" if relative_to_doc_root == File.expand_path(doc_dir)

            "#{attr}=\"#{base_url}#{relative_to_doc_root}\""
          else
            match
          end
        end
      end

      File.write(path, new_content) if new_content != content
    end

    puts "Finished converting links."
  end
end

task default: :test
