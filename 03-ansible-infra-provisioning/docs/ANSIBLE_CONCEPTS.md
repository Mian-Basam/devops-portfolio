# Ansible Concepts Used in This Repo

## Agentless over SSH

Ansible connects with SSH and runs small Python modules on the target. No
agent to install, which suits locked-down data-center servers.

## Inventory

A list of hosts and groups (`inventories/*/hosts.ini`). Groups such as
`webservers` drive both *where* plays run and *what* templates generate
(the LB upstream loops over `groups['webservers']`).

## Modules and idempotency

Modules describe the **desired state** (`state: present`, `state: started`)
rather than commands. Running the same play twice changes nothing the
second time. Where `command`/`shell` is unavoidable, `changed_when` tells
Ansible whether anything really changed.

## Roles

Reusable bundles: `tasks/`, `handlers/`, `templates/`, `files/`,
`defaults/`, `meta/`.

## Handlers

Run once at the end of a play, and only if notified by a task that changed
something. Example: editing the sshd config notifies `Restart sshd`.
`meta: flush_handlers` forces them to run immediately (used before health
checks in `webapp`).

## Variable precedence (simplified, low → high)

1. role `defaults/`
2. inventory `group_vars/all`
3. inventory `group_vars/<group>`
4. `host_vars/<host>`
5. play `vars`
6. play `vars_files`
7. role `vars/`
8. `set_fact` / `register`
9. **extra vars (`-e`) – always win**

Point 6 overriding point 5 caused a real bug in this repo's tests (see the README).

## Delegation

`delegate_to: lb01` runs a task on another host while still in the
context of the current one. The rolling update uses it to reconfigure the
load balancer while it iterates over web servers.

## Serial and failure control

`serial: 1` processes one host at a time. `max_fail_percentage: 0` aborts
the play on the first failure. Together they make releases safe.

## Check mode

`--check --diff` shows what *would* change without changing it. Always
run it before applying to production.

## Useful ad-hoc commands

```bash
ansible all -m ping
ansible webservers -m ansible.builtin.shell -a "uptime"
ansible all -m ansible.builtin.setup -a "filter=ansible_distribution*"
ansible web01 -b -m ansible.builtin.service -a "name=hello-dc state=restarted"
```
