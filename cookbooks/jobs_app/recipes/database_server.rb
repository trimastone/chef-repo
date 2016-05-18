#
# Cookbook Name:: jobs_app
# Recipe:: database_server
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

apt_update 'apt_get_update' do
  frequency 3600
  action :periodic
end

package 'postgresql-9.3' do
end

service 'postgresql' do
  action :nothing
end

cookbook_file '/etc/postgresql/9.3/main/postgresql.conf' do
  source 'postgresql.conf'
  owner 'postgres'
  group 'postgres'
  mode '0640'
  action :create
  notifies :restart, 'service[postgresql]'
end

cookbook_file '/etc/postgresql/9.3/main/pg_hba.conf' do
  source 'pg_hba.conf'
  owner 'postgres'
  group 'postgres'
  mode '0640'
  action :create
  notifies :restart, 'service[postgresql]'
end

secrets = Chef::EncryptedDataBagItem.load('jobs', "app_#{node.chef_environment}")
bash 'jobs_user' do
  user 'postgres'
  code <<-EOF
    createuser jobs_user
    psql -c "alter user jobs_user encrypted password '#{secrets['database_password']}';"
    EOF
  not_if "/usr/bin/psql -c '\\du' | grep jobs_user", :user => 'postgres'
  notifies :restart, 'service[postgresql]'
end

bash 'jobs_database' do
  user 'postgres'
  code <<-EOF
    createdb -E UTF8 jobs
    EOF
  not_if "/usr/bin/psql -c '\\l' | grep jobs", :user => 'postgres'
  notifies :restart, 'service[postgresql]'
end
