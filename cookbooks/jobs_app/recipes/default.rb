#
# Cookbook Name:: jobs_app
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

require 'base64'
require 'json'

if node.chef_environment == 'dev'
  login_user = 'vagrant'
else
  login_user = 'ubuntu'
end

local_user = 'jobs_user'
secrets = Chef::EncryptedDataBagItem.load('jobs', "app_#{node.chef_environment}")

apt_update 'apt_get_update' do
  frequency 3600
  action :periodic
end

package_list = ['python-virtualenv', 'postfix', 'python-setuptools', 'python-dev', 'libpq-dev', 'git', 'runit']

package_list.each do |package_name|
  package package_name do
  end
end

user 'jobs_user' do
  manage_home true
  home '/home/jobs_user'
  action :create
end

directory "/home/jobs_user/.ssh" do
  owner 'jobs_user'
  group 'jobs_user'
  mode '0700'
  action :create
end

file "/home/jobs_user/.ssh/id_rsa" do
  content Base64.decode64(secrets['repo_ssh_key'])
  mode '0600'
  owner 'jobs_user'
  group 'jobs_user'
end

template '/home/jobs_user/.ssh/config' do
  source 'ssh_config.erb'
  mode '0600'
  owner 'jobs_user'
  group 'jobs_user'
  variables({
     :aws_user_id => secrets['aws_user_id'],
  })
end

file "/home/jobs_user/.ssh/known_hosts" do
  content "git-codecommit.us-east-1.amazonaws.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCdut7aOM5Zh16OJ+GOP75O7x5oyHKAiA1ieuySetj/hAq4VrAuZV5R2TypZJcKBaripOtTc/Sr0FOU4YvxUla40PPH8N1lbDp6Pnc4BexKsrt2kz++TqIKx5FHmUQV3mit16kxRwHey3dv030+qXBDo3WPQjm2+JLoq0XcadpnCAMCd3ChaBnDRM+51GZbuEFilpZsxUchUzl0gseC+shYOBd7TqxTlIhj/56d/YF1kq7RMZYrwBnyYdVhpLeUJCeYjyx/O6FPSezNTLiinz5jjioWZATgn+G8feL/hIsk8g+7JoIcb2muUlymdxs+8l2lS+8MXqT0q9ohT+Knhb2j\n"
  mode '0600'
  owner 'jobs_user'
  group 'jobs_user'
end

file = File.read("/home/#{login_user}/stack_info.json")
stack_info = JSON.parse(file)

template '/home/jobs_user/secrets.json' do
  source 'secrets.json.erb'
  mode '0600'
  owner 'jobs_user'
  group 'jobs_user'
  variables({
     :database_password => secrets['database_password'],
     :database_ip => stack_info['database_ip'],
     :cookie_secret => secrets['cookie_secret'],
     :auth_secret => secrets['auth_secret'],
     :password_string => secrets['password_string'],
  })
end

#This will upgrade the system pip, need newer version of pip for poise-python to work.
python_runtime 'sys-python' do
  version '2.7'
end

python_package 'uwsgi' do
  action :install
end

python_virtualenv "/home/#{local_user}/pyramid16" do
  action :create
  user local_user
end

git "/home/#{local_user}/jobs" do
#  repository 'https://github.com/trimastone/testjobs.git'
  repository 'ssh://git-codecommit.us-east-1.amazonaws.com/v1/repos/jobs_dev'
  user local_user
  action :sync
  notifies :run, 'bash[setup_app]', :immediately
  notifies :run, 'bash[create_tables]', :immediately
end

bash 'setup_app' do
  user local_user
  cwd "/home/#{local_user}/jobs"
  code <<-EOF
    /home/#{local_user}/pyramid16/bin/python setup.py develop
    EOF
  action :nothing
end

bash 'create_tables' do
  user local_user
  cwd "/home/#{local_user}/jobs"
  code <<-EOF
    /home/#{local_user}/pyramid16/bin/python initialize_db.py #{node['jobs_app']['ini']} 
    EOF
  environment 'PYTHON_EGG_CACHE' => "/home/#{local_user}/.python-eggs"
  action :run
end

directory "/var/log/jobs" do
  user local_user
  mode '0755'
  action :create
end

runit_service "jobs" do
  restart_on_update false
  options({
    :app_ini => node['jobs_app']['ini'],
  })
end

directory "/home/jobs_user/Maildir" do
  user local_user
  mode '0755'
  action :create
end
directory "/home/jobs_user/Maildir/cur" do
  user local_user
  mode '0755'
  action :create
end
directory "/home/jobs_user/Maildir/new" do
  user local_user
  mode '0755'
  action :create
end
directory "/home/jobs_user/Maildir/tmp" do
  user local_user
  mode '0755'
  action :create
end
