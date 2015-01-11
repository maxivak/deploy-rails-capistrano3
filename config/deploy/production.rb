set :application, "myappname"
set :rails_env, 'production'
set :branch, "master"

server '123.45.67.89', user: 'myuser', roles: %w{web}, primary: true
set :deploy_to, "/var/www/apps/#{fetch(:application)}"


set :ssh_options, {
    forward_agent: true,
    #auth_methods: %w(password),
    #password: 'pass',
    user: 'myuser',
}


