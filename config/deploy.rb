# config valid only for current version of Capistrano
lock '3.3.5'


set :deploy_user, 'myuser'

role :app, %w{123.45.67.89}
role :web, %w{123.45.67.89}
role :db,  %w{123.45.67.89}



set :repo_url, 'ssh://myuser@123.45.67.89/path/to/repos/reponame.git'


# Default value for :scm is :git
set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 5


#
set :linked_dirs, fetch(:linked_dirs, []).push('bin', 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')
set :linked_dirs, fetch(:linked_dirs) + %w{public/uploads}
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')

set :config_dirs, %W{config config/environments/#{fetch(:stage)} public/system public/uploads}
set :config_files, %w{config/database.yml config/secrets.yml}


# precompile assets - locations that we will look for changed assets to determine whether to precompile
set :assets_dependencies, %w(app/assets lib/assets vendor/assets Gemfile config/routes.rb)


namespace :deploy do
  namespace :assets do
    desc "Precompile assets if changed"
    task :precompile do
      on roles(:app) do
        invoke 'deploy:assets:precompile_changed'
        #Rake::Task["deploy:assets:precompile_changed"].invoke
      end
    end
  end
end



#
before "deploy", "deploy:web:disable"
after "deploy", "deploy:web:enable"

