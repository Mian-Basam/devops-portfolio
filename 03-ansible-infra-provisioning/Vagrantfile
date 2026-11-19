# 3-VM lab that mimics a small data-center segment:
#   lb01  192.168.56.10  nginx load balancer
#   web01 192.168.56.11  app server
#   web02 192.168.56.12  app server
#
#   vagrant up          # create VMs (VirtualBox)
#   make provision      # run Ansible against them
NODES = {
  "lb01"  => { ip: "192.168.56.10", mem: 512 },
  "web01" => { ip: "192.168.56.11", mem: 512 },
  "web02" => { ip: "192.168.56.12", mem: 512 },
}

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false
  config.ssh.insert_key = true

  NODES.each do |name, opts|
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.network "private_network", ip: opts[:ip]
      node.vm.network "forwarded_port", guest: 80, host: 8080 if name == "lb01"
      node.vm.provider "virtualbox" do |vb|
        vb.name   = "ansible-lab-#{name}"
        vb.memory = opts[:mem]
        vb.cpus   = 1
        vb.linked_clone = true   # faster creation, less disk
      end
    end
  end
end
