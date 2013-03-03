begin
  require "bundler/gem_tasks"

  task :console do
    exec "pry", "-rbundler/setup", "-rplaything"
  end
rescue LoadError
  # don't need bundler for dev
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:default) do |spec|
  spec.ruby_opts = %w[-W]
end
