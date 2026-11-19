# Ansible Infrastructure Provisioning Lab

[![CI](https://github.com/Mian-Basam/ansible-infra-provisioning/actions/workflows/ci.yml/badge.svg)](https://github.com/Mian-Basam/ansible-infra-provisioning/actions)
![Ansible](https://img.shields.io/badge/Ansible-2.15+-EE0000?logo=ansible&logoColor=white)
![Vagrant](https://img.shields.io/badge/Vagrant-VirtualBox-1868F2?logo=vagrant&logoColor=white)
![ansible-lint](https://img.shields.io/badge/ansible--lint-production%20profile-success)
![Level](https://img.shields.io/badge/level-intermediate-orange)

> **Infrastructure as Code** for a small on-premises web tier: one Nginx
> load balancer and two application servers, built as **VirtualBox VMs
> with Vagrant** and configured entirely by **Ansible**, including
> **zero-downtime rolling updates** and controlled OS patching.
>
> **Portfolio level 3 of 5**: configuration management and virtualization.

---

## Table of contents

1. [Introduction](#1-introduction)
2. [Purpose of the project](#2-purpose-of-the-project)
3. [Architecture](#3-architecture)
4. [What gets configured](#4-what-gets-configured)
5. [Tools and technologies](#5-tools-and-technologies)
6. [File structure](#6-file-structure)
7. [How to run: `run.sh`](#7-how-to-run-runsh)
8. [Quick start](#8-quick-start)
9. [Playbooks](#9-playbooks)
10. [Zero-downtime rolling update](#10-zero-downtime-rolling-update)
11. [Testing and CI](#11-testing-and-ci)
12. [Bugs found by the tests](#12-bugs-found-by-the-tests)
13. [Skills demonstrated](#13-skills-demonstrated)
14. [Roadmap](#14-roadmap)
15. [Further documentation](#15-further-documentation)

---

## 1. Introduction

This project builds a miniature data-center segment on your laptop and
manages it entirely with code:

| VM | IP | Role |
|---|---|---|
| `lb01` | 192.168.56.10 | Nginx load balancer, reachable at `http://localhost:8080` |
| `web01` | 192.168.56.11 | Application server running the `hello-dc` service |
| `web02` | 192.168.56.12 | Application server running the `hello-dc` service |

**Vagrant** creates the three Ubuntu 22.04 VMs on **VirtualBox**, and
**Ansible** configures them: users and SSH keys, SSH hardening, firewall,
kernel settings, time sync, automatic security updates, monitoring agent,
the application and the load balancer. Nothing is configured by hand.

The same playbooks also work against an example **production inventory**;
only the inventory and its variables change, not the code.

## 2. Purpose of the project

**Problem it solves.** Configuring servers by hand over SSH does not
scale: every server ends up slightly different ("configuration drift"),
nobody remembers what was changed, and rebuilding a broken server takes
hours. Releasing a new app version by hand usually means downtime.

**Goals**

| Goal | How the project meets it |
|---|---|
| Describe servers as code | Ansible roles and inventories define the full state of every server |
| Repeatable and idempotent | Running `provision` twice gives `changed=0`; CI checks this |
| Secure by default | Key-only SSH, no root login, UFW default-deny, sysctl hardening, sandboxed systemd unit |
| Release without downtime | `rolling_update.yml` drains, updates and re-adds one server at a time |
| Patch safely | `patch.yml` upgrades one host at a time and reboots only when needed |
| Same code, many environments | Lab (Vagrant) and production inventories share the same roles |
| Tested before it touches a server | 15 offline checks + lint run without any VMs |

**Who it is for:** engineers learning Ansible and virtualization, and
anyone who needs an example of how on-prem servers are provisioned,
updated and patched in a controlled way.

**Where it fits:** projects 1 and 2 ran on a single machine. This project
manages a **fleet** of servers. Project 4 can monitor these VMs (they run
node_exporter), and project 5 uses the same Ansible approach to deploy.

## 3. Architecture

```
                         Host machine (your laptop)
     ┌────────────────────────────────────────────────────────────────────┐
     │  Ansible control node  ──SSH──┐                                    │
     │                               ▼                                    │
     │  ┌─────────── VirtualBox host-only network 192.168.56.0/24 ───────┐│
     │  │                                                                ││
     │  │   lb01 .10  nginx (least_conn)  :80  ◀── localhost:8080        ││
     │  │      │                    │                                    ││
     │  │      ▼                    ▼                                    ││
     │  │   web01 .11            web02 .12                               ││
     │  │   hello-dc :8000       hello-dc :8000     (systemd, sandboxed) ││
     │  │                                                                ││
     │  │   every node: hardened SSH · UFW · sysctl · chrony ·           ││
     │  │               unattended-upgrades · node_exporter :9100        ││
     │  └────────────────────────────────────────────────────────────────┘│
     └────────────────────────────────────────────────────────────────────┘
```

## 4. What gets configured

| Role | Applied to | Configures |
|---|---|---|
| `common` | all | Baseline packages, timezone, chrony time sync, `/etc/hosts`, admin users with SSH keys and sudo, SSH hardening (no root, no passwords, validated with `sshd -t`), sysctl kernel hardening, UFW default-deny firewall, unattended security upgrades, MOTD banner |
| `node_exporter` | all | Prometheus node_exporter binary and systemd unit; idempotent version check; port 9100 open only to the monitoring network |
| `webapp` | webservers | Dedicated system user, app code, env file, **sandboxed systemd unit** (`ProtectSystem=strict`, `NoNewPrivileges`), health check and version verification after deploy |
| `nginx_lb` | loadbalancers | Upstream pool **generated from the inventory**, `least_conn`, passive health checks (`max_fails`), retry on 502/503, `X-Upstream` header, `stub_status`; config validated with `nginx -t` before reload |

## 5. Tools and technologies

### Required to run

| Tool | Version | Used for | Install |
|---|---|---|---|
| VirtualBox | 7+ | hypervisor for the three VMs | [virtualbox.org](https://www.virtualbox.org/) |
| Vagrant | 2.3+ | creating and managing the VMs | [vagrantup.com](https://www.vagrantup.com/) |
| Python | 3.10+ | runs Ansible | python.org / `brew install python` |
| Ansible | 2.15+ | provisioning (`ansible`, `ansible-playbook`, `ansible-galaxy`) | `pip install ansible` |
| Ansible collections | – | `community.general`, `ansible.posix` | `./run.sh deps` |
| curl | any | traffic demo and tests | preinstalled |

About **1.5 GB** free RAM (three 512 MB VMs).

> **Apple Silicon note:** the `ubuntu/jammy64` box is x86-only, so the VMs
> do not run on M-series Macs. Use an Intel Mac or a Linux host. The
> offline tests (`./run.sh test`) use GNU tools and run best on Linux.

### Required to develop and test

| Tool | Used for | Install |
|---|---|---|
| ansible-lint | best-practice checks (production profile) | `pip install ansible-lint` |
| yamllint | YAML style | `pip install yamllint` |
| nginx, systemd-analyze (optional) | extra checks in the offline suite | Linux packages |

### Technology stack

| Category | Technologies |
|---|---|
| Configuration management | Ansible: roles, handlers, Jinja2 templates, tags, `serial`, `max_fail_percentage`, delegation, inventories, group_vars |
| Virtualization | Vagrant, VirtualBox, host-only networking, linked clones |
| Operating system | Ubuntu 22.04, systemd, UFW, sysctl, chrony, unattended-upgrades, OpenSSH |
| Load balancing | Nginx upstreams (`least_conn`, `max_fails`, `proxy_next_upstream`) |
| Application | Python 3 standard-library HTTP service (`hello-dc`) |
| Monitoring agent | Prometheus node_exporter |
| Quality / CI | ansible-lint, yamllint, `--syntax-check`, GitHub Actions |

## 6. File structure

```
03-ansible-infra-provisioning/
├── run.sh                               # ★ single entry point: ./run.sh help
├── Vagrantfile                          # defines lb01, web01, web02 (IPs, RAM, port 8080 forward)
├── ansible.cfg                          # default inventory, SSH settings, output format
├── requirements.yml                     # Ansible collections: community.general, ansible.posix
├── Makefile                             # make deps | up | provision | rolling | patch | test ...
├── README.md                            # this document
├── .ansible-lint                        # ansible-lint config (production profile)
├── .yamllint.yml                        # yamllint rules
│
├── inventories/
│   ├── vagrant/                         # the local lab
│   │   ├── hosts.ini                    #   lb01, web01, web02 and their groups
│   │   └── group_vars/
│   │       ├── all.yml                  #   admin users, timezone, firewall, monitoring network
│   │       ├── webservers.yml           #   app port, version, environment
│   │       └── loadbalancers.yml        #   LB port and algorithm
│   └── production/                      # example on-prem data center (same structure)
│       ├── hosts.ini
│       └── group_vars/{all,webservers,loadbalancers}.yml
│
├── playbooks/
│   ├── site.yml                         # full provisioning of every server (idempotent)
│   ├── rolling_update.yml               # zero-downtime release, one server at a time
│   ├── patch.yml                        # OS patching, reboot only when required
│   └── health_report.yml                # read-only fleet report
│
├── roles/
│   ├── common/                          # baseline for every server
│   │   ├── tasks/main.yml               #   packages, time, hosts, sysctl, upgrades, motd
│   │   ├── tasks/users.yml              #   admin users, SSH keys, sudo
│   │   ├── tasks/ssh.yml                #   SSH hardening (validated with sshd -t)
│   │   ├── tasks/firewall.yml           #   UFW default deny + allowed ports
│   │   ├── templates/sshd_hardening.conf.j2
│   │   ├── templates/motd.j2            #   login banner
│   │   ├── handlers/main.yml            #   restart sshd
│   │   ├── defaults/main.yml            #   default variables
│   │   └── meta/main.yml                #   role metadata
│   ├── node_exporter/                   # Prometheus host metrics agent
│   │   ├── tasks/main.yml               #   user, download, version check, service
│   │   ├── templates/node_exporter.service.j2
│   │   └── handlers/ defaults/ meta/
│   ├── webapp/                          # the demo application
│   │   ├── files/app.py                 #   hello-dc: /, /health, drain support, clean SIGTERM
│   │   ├── tasks/main.yml               #   user, code, env file, unit, health + version check
│   │   ├── templates/hello-dc.service.j2#   sandboxed systemd unit
│   │   ├── templates/app.env.j2         #   APP_VERSION, APP_PORT, APP_ENV
│   │   └── handlers/ defaults/ meta/
│   └── nginx_lb/                        # the load balancer
│       ├── tasks/main.yml               #   install nginx, deploy config, enable site
│       ├── tasks/set_backends.yml       #   drain / undrain servers (used by rolling update)
│       ├── templates/lb.conf.j2         #   upstream pool generated from the inventory
│       └── handlers/ defaults/ meta/    #   validate (nginx -t) then reload
│
├── tests/
│   ├── run_tests.sh                     # 15 offline checks (no VMs needed)
│   └── render_templates.yml             # renders templates locally for validation
│
├── docs/
│   ├── ARCHITECTURE.md                  # hosts, network, ports, data flow, variable hierarchy
│   ├── ROLES.md                         # every role's variables, tasks and handlers
│   ├── RUNBOOK.md                       # add a server, release, roll back, patch, recover
│   ├── VIRTUALIZATION.md                # hypervisors, VMs vs containers, vSphere concepts
│   └── ANSIBLE_CONCEPTS.md              # inventory, modules, idempotency, precedence, handlers
│
└── .github/workflows/ci.yml             # lint + offline tests + real run on the runner + idempotency check
```

## 7. How to run: `run.sh`

`run.sh` is the single entry point for this project and does not need
`make`. Set `INV=...` to target another inventory, for example
`INV=inventories/production/hosts.ini ./run.sh dry-run`.

| Command | What it does |
|---|---|
| `./run.sh help` | List all commands |
| `./run.sh doctor` | Check Vagrant, VirtualBox, Ansible and linters (warns on Apple Silicon) |
| `./run.sh all` | **deps + up + ping + provision**: the whole lab in one command |
| `./run.sh deps` | Install the Ansible collections |
| `./run.sh up` | Create / start the three VMs |
| `./run.sh status` | `vagrant status` |
| `./run.sh ssh <host>` | SSH into a VM, e.g. `./run.sh ssh web01` |
| `./run.sh ping` | Check Ansible can reach every host |
| `./run.sh provision` | Run the full site playbook |
| `./run.sh dry-run` | Show what would change (`--check --diff`) |
| `./run.sh rolling [version]` | Zero-downtime release (default `1.1.0`) |
| `./run.sh patch` | OS patching, one host at a time |
| `./run.sh report` | Fleet health report |
| `./run.sh traffic` | Curl the load balancer in a loop (Ctrl-C to stop) |
| `./run.sh lint` | ansible-lint + yamllint |
| `./run.sh test` | 15 offline checks |
| `./run.sh down` | Stop the VMs |
| `./run.sh destroy` | Delete the VMs |

From the portfolio root you can also run `./run.sh 03 <command>`.

## 8. Quick start

```bash
git clone https://github.com/Mian-Basam/ansible-infra-provisioning.git
cd ansible-infra-provisioning

./run.sh doctor     # 1. check tools
./run.sh all        # 2. collections + VMs + ping + provision (~5 min the first time)
./run.sh traffic    # 3. watch requests alternate between servers
```

```
{"host": "web01", "version": "1.0.0", "env": "lab"}
{"host": "web02", "version": "1.0.0", "env": "lab"}
{"host": "web01", "version": "1.0.0", "env": "lab"}
{"host": "web02", "version": "1.0.0", "env": "lab"}
```

Run `./run.sh provision` again: the summary shows `changed=0` on every
host, which proves the playbooks are **idempotent**.

## 9. Playbooks

| Playbook | Command | Purpose |
|---|---|---|
| `site.yml` | `./run.sh provision` | Build or converge every server to the declared state |
| `site.yml --check --diff` | `./run.sh dry-run` | Preview changes without applying them |
| `rolling_update.yml` | `./run.sh rolling 1.1.0` | Release a new app version with no downtime |
| `patch.yml` | `./run.sh patch` | `apt dist-upgrade` one host at a time, reboot only if required, wait for health |
| `health_report.yml` | `./run.sh report` | Uptime, load, memory, disk and service states for all hosts |

Run only part of the configuration with tags or limits:

```bash
ansible-playbook playbooks/site.yml --tags lb            # only the load balancer
ansible-playbook playbooks/site.yml --limit web02        # only one server
```

## 10. Zero-downtime rolling update

```bash
# terminal 1: continuous traffic
./run.sh traffic

# terminal 2: release
./run.sh rolling 1.1.0
```

For each web server, one at a time (`serial: 1`), the playbook:

1. **Drains** the server: it re-renders the LB config with that server
   marked `down`, validates it with `nginx -t`, and reloads gracefully.
2. **Waits** 5 seconds for in-flight requests to finish.
3. **Deploys** the new version, waits for `/health`, and checks that the
   running version equals the requested one.
4. **Returns** the server to the pool and verifies a request through the LB.

`max_fail_percentage: 0` stops the release on the first failure, so at
most one server is affected. Terminal 1 keeps getting answers throughout.

## 11. Testing and CI

`./run.sh test` runs 15 checks **without any VMs**:

```
PASS  ansible-lint (production profile)
PASS  yamllint
PASS  syntax-check all playbooks
PASS  LB upstream generated from inventory (web01, web02)
PASS  LB algorithm applied
PASS  draining web01 marks only web01 down
PASS  rendered LB config passes nginx -t
PASS  sshd hardening rendered
PASS  systemd unit verifies
PASS  app /health returns 200
PASS  app reports configured version
PASS  app returns 503 while draining
PASS  app healthy again after drain removed
PASS  app returns 404 for unknown paths
PASS  app exits cleanly on SIGTERM (systemctl stop)
all tests passed
```

GitHub Actions runs the same suite. It then applies the roles to the CI
runner itself, runs them a **second time to prove idempotency**
(`changed=0`), and sends a request through the provisioned load balancer.

## 12. Bugs found by the tests

These were real defects caught while writing the suite, and they show why
testing infrastructure code matters:

| Bug | Symptom | Fix |
|---|---|---|
| SIGTERM handler called `httpd.shutdown()` on the serving thread | `systemctl stop` would hang for 90s until SIGKILL; the rolling update would stall on every host | Run `shutdown()` in a separate thread; regression test added |
| Variable precedence: `vars_files` overrode play `vars` | Drain test silently rendered no host as `down` | Pass the value as an extra var (highest precedence); test now fails loudly |
| `A && B` checks under `set -e` | A failing check skipped its PASS line but did not fail the suite | `check()` helper that exits non-zero on failure |

## 13. Skills demonstrated

Ansible roles, handlers, templates (Jinja2), tags, `serial` and
`max_fail_percentage`, delegation, idempotency · inventory-driven
configuration across environments · Linux hardening (SSH, UFW, sysctl,
sudoers, systemd sandboxing) · Nginx load balancing · Vagrant/VirtualBox
virtualization · OS patch management · ansible-lint (production
profile), yamllint, CI.

## 14. Roadmap

- [ ] Ansible Vault for secrets (SSH keys, app credentials)
- [ ] Molecule scenarios per role
- [ ] Second load balancer with keepalived (VRRP virtual IP)
- [ ] Prometheus server role scraping node_exporter (see Project 4)

## 15. Further documentation

| Document | Contents |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Hosts, network, ports, data flow, variable hierarchy |
| [docs/ROLES.md](docs/ROLES.md) | Every role's variables, tasks and handlers |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Add a server, release, roll back, patch, rotate users, recover |
| [docs/VIRTUALIZATION.md](docs/VIRTUALIZATION.md) | Hypervisors, VMs vs containers, VMware vSphere concepts mapped to this lab |
| [docs/ANSIBLE_CONCEPTS.md](docs/ANSIBLE_CONCEPTS.md) | Inventory, modules, idempotency, variable precedence, handlers, delegation |

---

**Author:** Basil Ahtisham · [LinkedIn](https://linkedin.com/in/mianbasil) · [GitHub](https://github.com/Mian-Basam)
