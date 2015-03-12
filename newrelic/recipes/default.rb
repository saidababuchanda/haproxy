# install newrelic for server
execute 'install-server-newrelic'do 
  command 'rpm -Uvh http://download.newrelic.com/pub/newrelic/el5/i386/newrelic-repo-5-3.noarch.rpm'
  not_if "rpm -qa | grep -q 'newrelic'"
end

package 'newrelic-sysmond' do
  action :upgrade
end



service "newrelic-sysmond" do
  action :start
end

app_config = node['deploy']['matinee']
if (node['opsworks']['instance']['layers'].include?('rails-app') and app_config)
  template "#{app_config[:deploy_to]}/shared/config/newrelic.yml" do
    source 'newrelic.yml.erb'
    mode '0660'
    owner 'root'
    group 'root'
    variables(:application_name => 'matinee', :license_key => node['newrelic']['license_key'])
    # only generate a file if there is newrelic
    not_if do
      node['newrelic'].blank?
    end
  end
elsif node['opsworks']['instance']['layers'].include?('php-app')
  download_file_path = ::File.join(Chef::Config[:file_cache_path], "#{node['newrelicphp']['source']['path']}.tar.gz")
  remote_file download_file_path do
    source node['newrelicphp']['source']['url']
    checksum node['newrelicphp']['source']['checksum']
    action :create_if_missing
  end
  
  ruby_block "Validating checksum for the downloaded tarball" do
    block do
      checksum = Digest::MD5.file(download_file_path).hexdigest
      if checksum != node['newrelicphp']['source']['checksum']
        raise "Checksum of the downloaded file #{checksum} does not match known checksum #{node['newrelicphp']['source']['checksum']}"
      end
    end
  end
  
  bash 'install-newrelic-php' do 
    cwd Chef::Config[:file_cache_path]
    environment('NR_INSTALL_SILENT' => 'true', 'NR_INSTALL_KEY' => node['newrelic']['license_key'])
    code <<-EOH
      tar xzf #{node['newrelicphp']['source']['path']}.tar.gz
      cd #{node['newrelicphp']['source']['path']}
      ./newrelic-install install
    EOH
  end 
end


