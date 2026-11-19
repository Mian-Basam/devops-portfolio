.PHONY: help deps up provision rolling patch report lint test ping ssh-web01 down destroy
INV ?= inventories/vagrant/hosts.ini
VERSION ?= 1.1.0

help:       ## list targets
	@grep -E '^[a-z0-9-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-11s %s\n", $$1, $$2}'
deps:       ## install Ansible collections
	ansible-galaxy collection install -r requirements.yml
up:         ## create the 3 VMs
	vagrant up
ping:       ## check Ansible can reach every host
	ansible -i $(INV) all -m ping
provision:  ## run the full site playbook
	ansible-playbook -i $(INV) playbooks/site.yml
rolling:    ## zero-downtime release: make rolling VERSION=1.2.0
	ansible-playbook -i $(INV) playbooks/rolling_update.yml -e webapp_version=$(VERSION)
patch:      ## OS patching, one host at a time
	ansible-playbook -i $(INV) playbooks/patch.yml
report:     ## fleet health report
	ansible-playbook -i $(INV) playbooks/health_report.yml
dry-run:    ## show what would change (check + diff)
	ansible-playbook -i $(INV) playbooks/site.yml --check --diff
lint:       ## ansible-lint + yamllint
	ansible-lint && yamllint -c .yamllint.yml .
test:       ## offline test suite (no VMs needed)
	./tests/run_tests.sh
down:       ## stop VMs
	vagrant halt
destroy:    ## delete VMs
	vagrant destroy -f
