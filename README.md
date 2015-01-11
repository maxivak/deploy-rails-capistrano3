deploy rails app with capistrano3
=======================

Example of deploying Rails application to a Linux server with Nginx+Passenger.

Find all necessary files in the repository and read about features below:

- [text here](#setup)


# Capistrano 3

## Initialize Capistrano

Gemfile
```ruby
group :development do
  gem 'capistrano',  '~> 3.1'
  gem 'capistrano-rails', '~> 1.1'
 ...
end

```

Run the command
```bash
cap install
```

This command will create files:
```
Capfile
config/deploy.rb
config/deploy/production.rb
config/deploy/staging.rb
lib/capistrano/tasks          # directory
```

## Setup
<a name="setup"></a>

Gemfile
```ruby
group :development do
  gem 'capistrano',  '~> 3.1'
  gem 'capistrano-rails', '~> 1.1'
  #gem 'capistrano-bundler', '~> 1.1'
  gem 'capistrano-rvm',   '~> 0.1'

end

```


Capfile
```ruby
require 'capistrano/rvm'
# require 'capistrano/rbenv'
# require 'capistrano/chruby'
#require 'capistrano/bundler'
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'
```


## Restart server


### Passenger

Restart application after deploy:

```ruby
namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end
  after :publishing, :restart
end

```

You can run this command manually to restart the app
```
cap production deploy:restart
```

This gem provides more functionality on working with Passenger: https://github.com/capistrano/passenger


## Linked files, dirs

Some of the files should be stored in shared folder and shared across all releases.
File from the 'linked_files' list are symlinked to files in shared folder.

For example, you may want to store users' uploaded files in public/uploads directory. This directory should not new in each release after deploy.

```ruby
set :linked_dirs, fetch(:linked_dirs, []).push('bin', 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')
set :linked_dirs, fetch(:linked_dirs) + %w{public/uploads}

set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')

```

Note! You need to copy linked files to the server before deploy _manually_. The files are not copied to the shared folder by Capistrano. 


## Config files

Task to copy files to shared directory:

```ruby

set :config_dirs, %W{config config/environments/#{fetch(:stage)} public/uploads}
set :config_files, %w{config/database.yml config/secrets.yml}


namespace :deploy do
  desc 'Copy files from application to shared directory'
  ## copy the files to the shared directories
  task :copy_config_files do
    on roles(:app) do
      # create dirs
      fetch(:config_dirs).each do |dirname|
        path = File.join shared_path, dirname
        execute "mkdir -p #{path}"
      end

      # copy config files
      fetch(:config_files).each do |filename|
        remote_path = File.join shared_path, filename
        upload! filename, remote_path
      end

    end
  end
end

```


run the command:
```
cap production deploy:copy_config_files
```



## Precompile assets

By default assets are precompiled every time during the deploy process.
rake assets:precompile can take up a noticable amount of time of a deploy.

Run the task manually:
```
cap production deploy:assets:precompile
```


### Precompile assets only after changes

We will redefine default precompile task to check for changed files.
Assets will be precompiled only if changes are detected in certain files or folders defined by variable :assets_dependencies.


```ruby

# set the locations that we will look for changed assets to determine whether to precompile
set :assets_dependencies, %w(app/assets lib/assets vendor/assets Gemfile config/routes.rb)


# clear the previous precompile task
Rake::Task["deploy:assets:precompile"].clear_actions
class PrecompileRequired < StandardError; end

namespace :deploy do
  namespace :assets do
    desc "Precompile assets"
    task :precompile do
      on roles(:app) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            begin

              # find the most recent release
              latest_release = capture(:ls, '-xr', releases_path).split[1]

              # precompile if this is the first deploy
              raise PrecompileRequired unless latest_release

              #
              latest_release_path = releases_path.join(latest_release)

              # precompile if the previous deploy failed to finish precompiling
              execute(:ls, latest_release_path.join('assets_manifest_backup')) rescue raise(PrecompileRequired)

              fetch(:assets_dependencies).each do |dep|
                # execute raises if there is a diff
                execute(:diff, '-Naur', release_path.join(dep), latest_release_path.join(dep)) rescue raise(PrecompileRequired)
              end

              warn("-----Skipping asset precompile, no asset diff found")

              # copy over all of the assets from the last release
              execute(:cp, '-r', latest_release_path.join('public', fetch(:assets_prefix)), release_path.join('public', fetch(:assets_prefix)))

            rescue PrecompileRequired
              warn("----Run assets precompile")

              execute(:rake, "assets:precompile")
            end
          end
        end
      end
    end
  end
end

```

This solution was found in the post 
https://coderwall.com/p/aridag/only-precompile-assets-when-necessary-rails-4-capistrano-3



### Precompile assets locally

Sometimes you may want to  precompile assets locally and upload them to the server.

Define a task to compile assets locally and copy them to the server. If your local machine is on Windows, make sure you have zip archiver (for example, 7zip).


```ruby

namespace :deploy do
  namespace :assets do

    desc 'Run the precompile task locally and upload to server'
    task :precompile_locally_archive do
      on roles(:app) do
        run_locally do
          if RUBY_PLATFORM =~ /(win32)|(i386-mingw32)/
            execute 'del "tmp/assets.tar.gz"' rescue nil
            execute 'rd /S /Q "public/assets/"' rescue nil

            # precompile
            with rails_env: fetch(:rails_env) do
              execute 'rake assets:precompile'
            end
            #execute "RAILS_ENV=#{rails_env} rake assets:precompile"

            # use 7zip to archive
            execute '7z a -ttar assets.tar public/assets/'
            execute '7z a -tgzip assets.tar.gz assets.tar'
            execute 'del assets.tar'
            execute 'move assets.tar.gz tmp/'
          else
            execute 'rm tmp/assets.tar.gz' rescue nil
            execute 'rm -rf public/assets/*'

            with rails_env: fetch(:rails_env) do
              execute 'rake assets:precompile'
            end

            execute 'touch assets.tar.gz && rm assets.tar.gz'
            execute 'tar zcvf assets.tar.gz public/assets/'
            execute 'mv assets.tar.gz tmp/'
          end
        end

        # Upload precompiled assets
        execute 'rm -rf public/assets/*'
        upload! "tmp/assets.tar.gz", "#{release_path}/assets.tar.gz"
        execute "cd #{release_path} && tar zxvf assets.tar.gz && rm assets.tar.gz"
      end
    end

  end
end

```



If you don't want to archive the assets before upload, use this task which will copy folder /public/assets to the server file by file.

```ruby
namespace :deploy do
  namespace :assets do

    desc 'Precompile assets locally and upload to server'
    task :precompile_locally_copy do
      on roles(:app) do
        run_locally do
          with rails_env: fetch(:rails_env) do
            #execute 'rake assets:precompile'
          end
        end

        execute "cd #{release_path} && mkdir public" rescue nil
        execute "cd #{release_path} && mkdir public/assets" rescue nil
        execute 'rm -rf public/assets/*'

        upload! 'public/assets', "#{release_path}/public", recursive: true

      end
    end
  end
end
```

Run the task:
```ruby
cap production deploy:assets:precompile_locally
```

To replace default precompile task with the new task:

```ruby
namespace :deploy do
  namespace :assets do
    desc "Precompile assets"
    task :precompile do
      on roles(:app) do
        invoke 'deploy:assets:precompile_locally'
        #Rake::Task["deploy:assets:precompile_locally"].invoke
      end
    end    
  end  
end
```



## Maintenance page

Use these tasks if you need to show a certain page on site to visitors while the app is updating:

```ruby

cap production deploy:web:enable 
cap production deploy:web:disable

```

Create a page 'app/views/admin/maintenance.html.haml'
```ruby
<div style="width:100%;">
<div style="width:900px; margin:0 auto;">
  <h1>Site is offline for <%= reason ? reason : 'maintenance' %></h1>
  <p>We're currently offline for <%= reason ? reason : 'maintenance' %> as of <%= Time.now.utc.strftime('%H:%M %Z') %>.</p>
  <p>Sorry for the inconvenience.
  <p>We'll be back <%= deadline ? "by #{deadline}" : 'shortly' %>.</p>

</div></div>

```

The task will compile the template and put it in 'shared/public/system/maintenance.html'


Tasks:
```ruby
namespace :deploy do
  namespace :web do
    desc <<-DESC
      Present a maintenance page to visitors.
        $ cap deploy:web:disable REASON="a hardware upgrade" UNTIL="12pm Central Time"
    DESC

    task :disable do
      on roles(:web) do
        #require 'erb'

        execute "rm #{shared_path}/system/maintenance.html"

        reason = ENV['REASON']
        deadline = ENV['UNTIL']
        template = File.read('app/views/admin/maintenance.html.haml')
        page = ERB.new(template).result(binding)

        put page, "#{shared_path}/system/maintenance.html", :mode => 0644
      end

    end

    task :enable do
      on roles(:web) do
        execute "rm #{shared_path}/system/maintenance.html"
      end
    end

  end
end


The solution was found here: http://stackoverflow.com/questions/2244263/capistrano-to-deploy-rails-application-how-to-handle-long-migrations.


Run the tasks before and after deploy:

```ruby
before "deploy", "deploy:web:disable"
after "deploy", "deploy:web:enable"
```


Now we need to show this page on site. You need to modify settings on your web server to use this maintenance page.


### Nginx

If you use Nginx as a web server add this code to the server's configuration:

```
server {
  passenger_enabled on;

  server_name yoursite.com;
  ...

  if (-f $document_root/system/maintenance.html) {
    rewrite ^(.*)$ /system/maintenance.html break;
  }


}
```
 
 

## Delete old repos

```
set :keep_releases, 5
```
Keep only several releases. Old releases will be deleted automatically after successful deploy.



## Deploy

### Before deploy

```
cap production deploy:copy_config_files
```

Run this command after you change your config files (like config/database.yml)

### Deploy

```
cap production deploy

cap <stage_name> deploy
```


### Deploy without precompiling assets





## References

Tutorials about deploy
* http://www.talkingquickly.co.uk/2014/01/deploying-rails-apps-to-a-vps-with-capistrano-v3/
* http://vladigleba.com/blog/2014/04/04/deploying-rails-apps-part-5-configuring-capistrano/
