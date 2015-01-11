
# maintenance page
namespace :deploy do
  namespace :web do
    desc <<-DESC
      Present a maintenance page to visitors.
        $ cap deploy:web:disable REASON="a hardware upgrade" UNTIL="12pm Central Time"
    DESC

    task :disable do
      on roles(:web) do
        execute "rm #{shared_path}/system/maintenance.html" rescue nil

        require 'erb'
        reason = ENV['REASON']
        deadline = ENV['UNTIL']
        template = File.read('app/views/admin/maintenance.html.haml')
        #page = ERB.new(template).result(binding)
        content = ERB.new(template).result(binding)

        path = "public/system/maintenance.html"
        File.open(path, "w") { |f| f.write content }

        upload! path, "#{shared_path}/public/system/maintenance.html", :mode => 0644
      end

    end

    task :enable do
      on roles(:web) do
        execute "rm #{shared_path}/public/system/maintenance.html"
      end
    end

  end
end