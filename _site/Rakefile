require 'time'

# Take from http://stackoverflow.com/a/25745685
desc 'create a new draft post'
task :post do
	title = ENV['title']
  unless title
    puts "Please set 'title' env variable and try again"
    exit(1)
  end

	slug  = "#{Date.today}-#{title.downcase.gsub(/[^\w]+/, '-')}"
	file  = File.join(File.dirname(__FILE__), '_posts', slug + '.md')

	File.open(file, 'a') do |f|
		f << <<-EOS.gsub(/^     /, '')
---
layout: post
title: #{title}
---

{{ page.title }}
================

<p class="meta">#{Date.today.day} #{Date::MONTHNAMES[Date.today.month]} #{Date.today.year}</p>

		EOS
	end

	system("#{ENV['EDITOR']} #{file}")
end
