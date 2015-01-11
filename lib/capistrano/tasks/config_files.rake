# copy config files
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
