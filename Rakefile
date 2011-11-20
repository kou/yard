require File.dirname(__FILE__) + '/lib/yard'
require File.dirname(__FILE__) + '/lib/yard/rubygems/specification'
require 'rbconfig'

YARD::VERSION.replace(ENV['YARD_VERSION']) if ENV['YARD_VERSION']
WINDOWS = (RbConfig::CONFIG['host_os'] =~ /mingw|win32|cygwin/ ? true : false) rescue false
SUDO = WINDOWS ? '' : 'sudo'

task :default => :specs

desc "Builds the gem"
task :gem do
  Gem::Builder.new(eval(File.read('yard.gemspec'))).build
end

desc "Installs the gem"
task :install => :gem do 
  sh "#{SUDO} gem install yard-#{YARD::VERSION}.gem --no-rdoc --no-ri"
end

desc 'Run spec suite'
task :suite do
  ['ruby186', 'ruby18', 'ruby19', 'ruby192', 'ruby193', 'jruby'].each do |ruby|
    2.times do |legacy|
      next if legacy == 1 && ruby =~ /^jruby|186/
      puts "Running specs with #{ruby}#{legacy == 1 ? ' (in legacy mode)' : ''}"
      cmd = "#{ruby} -S rake specs SUITE=1 #{legacy == 1 ? 'LEGACY=1' : ''}"
      puts cmd
      system(cmd)
    end
  end
end

task :travis_ci do
  status = 0
  ENV['SUITE'] = '1'
  ENV['CI'] = '1'
  system "bundle exec rake specs"
  status = 1 if $?.to_i != 0
  if RUBY_VERSION >= '1.9' && RUBY_PLATFORM != 'java'
    puts ""
    puts "Running specs with in legacy mode"
    system "bundle exec rake specs LEGACY=1"
    status = 1 if $?.to_i != 0
  end
  exit(status)
end

begin
  hide = '_spec\.rb$,spec_helper\.rb$,ruby_lex\.rb$,autoload\.rb$'
  if YARD::Parser::SourceParser.parser_type == :ruby
    hide += ',legacy\/.+_handler'
  else
    hide += ',ruby_parser\.rb$,ast_node\.rb$,handlers\/ruby\/[^\/]+\.rb$'
  end

  require 'rspec'
  require 'rspec/core/rake_task'

  desc "Run all specs"
  RSpec::Core::RakeTask.new("specs") do |t|
    $DEBUG = true if ENV['DEBUG']
    t.rspec_opts = ENV['SUITE'] ? ['--format', 'progress'] : ["--colour", "--format", "documentation"]
    t.rspec_opts += ["--require", File.join(File.dirname(__FILE__), 'spec', 'spec_helper')]
    t.rspec_opts += ['-I', YARD::ROOT]
    t.pattern = "spec/**/*_spec.rb"
    t.verbose = $DEBUG ? true : false
  
    if ENV['RCOV']
      t.rcov = true 
      t.rcov_opts = ['-x', hide]
    end
  end
  task :spec => :specs
rescue LoadError
  begin # Try for rspec 1.x
    require 'spec'
    require 'spec/rake/spectask'
    
    Spec::Rake::SpecTask.new("specs") do |t|
      $DEBUG = true if ENV['DEBUG']
      t.spec_opts = ["--format", "specdoc", "--colour"]
      t.spec_opts += ["--require", File.join(File.dirname(__FILE__), 'spec', 'spec_helper')]
      t.pattern = "spec/**/*_spec.rb"

      if ENV['RCOV']
        t.rcov = true 
        t.rcov_opts = ['-x', hide]
      end
    end
    task :spec => :specs
  rescue LoadError
    warn "warn: RSpec tests not available. `gem install rspec` to enable them."
  end
end

YARD::Rake::YardocTask.new do |t|
  t.options += ['--title', "YARD #{YARD::VERSION} Documentation"]
end

namespace :i18n do
  supported_locales = ["ja"]

  base_name = "yard"
  locale_base_dir = "locale"
  system_locale_base_dir = "system-locale"
  namespace :pot do
    yard_pot = "#{locale_base_dir}/#{base_name}.pot"
    YARD::Rake::YardocTask.new(:yard) do |t|
      t.options += ['--output', 'locale', '--format', 'pot']
    end
    file yard_pot => :yard

    system_yard_pot = "#{system_locale_base_dir}/#{base_name}.pot"
    targets = FileList["lib/**/*.rb", "templates/**/*.{erb,rb}"]
    file system_yard_pot => targets do
      rm_f(system_yard_pot)
      sh("rgettext", "--output", system_yard_pot, *targets)
    end
    task :system => system_yard_pot
  end

  namespace :po do
    [[:yard, "locale"],
     [:system, "system-locale"]].each do |task_namespace, base_dir|
      namespace task_namespace do
        supported_locales.each do |locale|
          locale_dir = "#{base_dir}/#{locale}"
          po = "#{locale_dir}/#{base_name}.po"
          pot = "#{base_dir}/#{base_name}.pot"

          directory locale_dir
          file po => [locale_dir, pot] do
            if File.exist?(po)
              sh("msgmerge", "--update", "--sort-by-file", po, pot)
            else
              sh("msginit",
                 "--input", pot,
                 "--output", po,
                 "--locale", locale)
            end
          end

          task locale => po
        end
      end
    end
  end
end
