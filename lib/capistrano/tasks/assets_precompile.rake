# clear the previous precompile task
Rake::Task["deploy:assets:precompile"].clear_actions
class PrecompileRequired < StandardError; end


namespace :deploy do
  namespace :assets do
    desc "Precompile assets if changed"
    task :precompile_changed do
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
                #execute(:du, '-b', release_path.join(dep)) rescue raise(PrecompileRequired)
                #execute(:du, '-b', latest_release_path.join(dep)) rescue raise(PrecompileRequired)

                # execute raises if there is a diff
                execute(:diff, '-Naur', release_path.join(dep), latest_release_path.join(dep)) rescue raise(PrecompileRequired)
              end

              warn("-----Skipping asset precompile, no asset diff found")

              # copy over all of the assets from the last release
              execute(:cp, '-rf', latest_release_path.join('public', fetch(:assets_prefix)), release_path.join('public', fetch(:assets_prefix)))

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
