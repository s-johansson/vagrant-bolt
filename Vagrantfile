require 'vagrant-openstack-provider'
require 'vagrant-bolt'

Vagrant.configure('2') do |config|

  config.ssh.username = 'centos'
  config.ssh.insert_key = true
  config.ssh.private_key_path = '~/.ssh/id_rsa-acceptance'
  config.vm.synced_folder ".", "/vagrant", type: "rsync",
    rsync__exclude: [".git/", ".bundle"]

  config.vm.provider :openstack do |os|
    os.openstack_auth_url = ENV['OS_AUTH_URL']
    os.username           = ENV['OS_USERNAME']
    os.password           = ENV['OS_PASSWORD']
    os.project_name       = ENV['OS_PROJECT_NAME']
    os.domain_name        = ENV['OS_PROJECT_DOMAIN_ID']
    os.identity_api_version = '3'
    os.floating_ip_pool   = 'external'
    os.floating_ip_pool_always_allocate = true
    os.keypair_name       = 'id_rsa-acceptance_pub'
    os.networks           = ['network1']
    os.security_groups    = ['default']
    os.flavor             = 'vol.small'
    os.volume_boot        = { 'size': '16', 'delete_on_destroy': true, 'image': 'centos_7_x86_64' }
  end
  config.vm.define 'server-1' do |s|
    s.vm.provider :openstack do |os, override|
    end
    s.vm.provision :bolt do |config|
      config.task             = "A Task"
      config.plan             = "A Plan"
    end
  end
end
