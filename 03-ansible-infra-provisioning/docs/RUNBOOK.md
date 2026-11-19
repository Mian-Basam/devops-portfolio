# Runbook

## Add a new web server

1. Create the VM (lab: add `web03` to `NODES` in the `Vagrantfile`, then `vagrant up web03`).
2. Add it to the inventory under `[webservers]`.
3. Provision only the new host, then update the load balancer:

```bash
ansible-playbook playbooks/site.yml --limit web03
ansible-playbook playbooks/site.yml --limit loadbalancers --tags lb
```

The LB config is generated from the inventory, so no manual nginx edits are needed.

## Release a new version

```bash
make rolling VERSION=1.2.0
curl -sI localhost:8080/ | grep X-Upstream
```

## Roll back

A rollback is a rolling update to the previous version:

```bash
make rolling VERSION=1.1.0
```

## Take a server out for maintenance

```bash
ansible-playbook playbooks/rolling_update.yml --limit web02 -e webapp_version=<current>   # quick drain/redeploy
# or manually: in lb.conf mark the server "down", then: nginx -t && systemctl reload nginx
```

## Patch the OS

```bash
make patch                       # one host at a time
ansible-playbook playbooks/patch.yml --limit lb01
```

The playbook reboots only when `/var/run/reboot-required` exists, then
waits until the app is healthy before moving to the next host.

## Onboard or offboard an admin

* Onboard: add an entry to `admin_users` in `group_vars/all.yml`, then `ansible-playbook playbooks/site.yml --tags common`.
* Offboard: move the name to `removed_users` and run the same command. Keys are managed with `exclusive: true`, so removed keys are deleted from servers.

## A web server is unhealthy

```bash
ansible web01 -m ansible.builtin.command -a "systemctl status hello-dc" -b
ansible web01 -m ansible.builtin.command -a "journalctl -u hello-dc -n 50 --no-pager" -b
ansible-playbook playbooks/site.yml --limit web01 --tags app     # re-converge
```

Users don't notice in the meantime: nginx retries failed requests on the
healthy backend.

## Locked out by firewall or SSH change

Lab: `vagrant ssh web01` uses the VirtualBox console path, then `sudo ufw disable`.
Production: use the hypervisor console (vSphere web console / iDRAC / iLO).
Prevention: always test with `--check --diff` and `--limit` one host first.
