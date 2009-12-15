require 'rubygems'

if File.read('lib/postgres-pr/version.rb') =~ /Version\s+=\s+"(\d+\.\d+\.\d+)"/
  version = $1
else
  raise "no version"
end

spec = Gem::Specification.new do |s|
  s.name = 'postgres-pr'
  s.version = version
  s.summary = 'A pure Ruby interface to the PostgreSQL (>= 7.4) database'
  s.requirements << 'PostgreSQL >= 7.4'

  s.files = (Dir['lib/**/*'] + Dir['test/**/*'] + 
             Dir['examples/**/*'])

  s.require_path = 'lib'

  s.author = "Michael Neumann"
  s.email = "mneumann@ntecs.de"
  s.homepage = "http://postgres-pr.rubyforge.org"
  s.rubyforge_project = "postgres-pr"
end
