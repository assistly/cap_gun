require 'rubygems'
require 'hoe'
require './lib/cap_gun.rb'

hoe = Hoe.new('cap_gun', CapGun::VERSION) do |p|
  p.rubyforge_name = 'thinkrelevance'
  p.author = ["Rob Sanheim", "Relevance"]
  p.email = 'opensource@thinkrelevance.com'
  p.summary = "Bang! You're deployed!"
  p.description = p.paragraphs_of('README.rdoc', 2..5).join("\n\n")
  p.url = p.paragraphs_of('README.rdoc', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.rdoc_pattern = /^(lib|bin|ext)|txt|rdoc$/
end

desc 'Test the cap_gun plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'spec/**/*_spec.rb'
  t.verbose = true
end

# Override RDoc to use allison template, and also use our .rdoc README as the main page instead of the default README.txt
Rake::RDocTask.new(:docs) do |rd|
  gem "allison"
  gem "markaby"
  rd.main = "README.rdoc"
  # rd.options << '-d' if RUBY_PLATFORM !~ /win32/ and `which dot` =~ /\/dot/ and not ENV['NODOT']
  rd.rdoc_dir = 'doc'
  files = hoe.spec.files.grep(hoe.rdoc_pattern)
  files -= ['Manifest.txt']
  rd.rdoc_files.push(*files)

  title = "#{hoe.name}-#{hoe.version} Documentation"
  title = "#{hoe.rubyforge_name}'s " + title if hoe.rubyforge_name != hoe.name
  rdoc_template = `allison --path`.strip << ".rb"
  rd.template = rdoc_template
  rd.options << "-t #{title}"
  rd.options << '--line-numbers' << '--inline-source'
end