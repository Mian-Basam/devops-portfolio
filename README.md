<div align="center">

# DevOps Portfolio

### Five progressive DevOps projects, from Linux scripting to CI/CD on Kubernetes

![Bash](https://img.shields.io/badge/Bash-Scripting-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-IaC-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-CI%2FCD-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)

[**Quick Start**](#how-to-use-the-runsh-scripts) &nbsp;•&nbsp; [**Tech Stack**](#tools-and-technologies-required)

</div>

---

<details>
<summary><b>Table of contents</b></summary>

- [Overview](#overview)
- [Purpose](#purpose)
- [How the projects connect](#how-the-projects-connect)
- [Project details](#project-details)
- [Tools and technologies required](#tools-and-technologies-required)
- [How to use: the run.sh scripts](#how-to-use-the-runsh-scripts)
- [Quick start per project](#quick-start-per-project)
- [Ports used](#ports-used)
- [Repository layout](#repository-layout)
- [Troubleshooting](#troubleshooting)

</details>

## Overview

Five hands-on DevOps projects that build on each other, from Linux shell
scripting up to a full CI/CD pipeline with Kubernetes and monitoring. Each
project is self-contained (its own README, docs, tests and CI workflow) and
each one can be started with a single **`run.sh`** script.

| # | Project | Level | What it shows |
|---|---|---|---|
| 1 | [Linux Ops Toolkit](01-linux-ops-toolkit/) | Basic | Bash scripts for server health, networking checks, backups, log analysis, self-healing services and user audits, scheduled with systemd timers |
| 2 | [TaskBoard: Docker three-tier app](02-docker-three-tier-app/) | Basic → Intermediate | Nginx + Flask/Gunicorn + PostgreSQL in Docker Compose with secrets, healthchecks, scaling and backup/restore |
| 3 | [Ansible infrastructure provisioning](03-ansible-infra-provisioning/) | Intermediate | Vagrant/VirtualBox VMs configured by Ansible: hardening, load balancer, app servers, zero-downtime rolling updates and patching |
| 4 | [Observability stack](04-observability-stack/) | Intermediate → Advanced | Prometheus, Grafana, Loki, Alertmanager, Blackbox, cAdvisor and Zabbix, with chaos endpoints to trigger real alerts |
| 5 | [PayFlow DevOps pipeline](05-payflow-devops-pipeline/) | Advanced (capstone) | Jenkins / TeamCity / Bitbucket / GitHub Actions pipelines, Trivy scanning, canary deploys with automatic rollback, Kubernetes |

---

## Purpose

This repository is a learning and demonstration portfolio for the core
skills of a DevOps / Site Reliability / Platform engineer:

* **Linux administration and scripting**: how to inspect, automate and
  schedule work on a server.
* **Containers**: how to package and run a multi-service application
  safely with Docker.
* **Infrastructure as Code**: how to build and configure servers in a
  repeatable way with Ansible and Vagrant.
* **Observability**: how to collect metrics and logs, build dashboards and
  design alerts that page the right person.
* **CI/CD and release engineering**: how code goes from a `git push` to a
  tested, scanned and safely deployed release, on VMs or on Kubernetes.

Every project is runnable on a laptop, has automated tests, and comes with
documentation (architecture, runbooks, troubleshooting) in its `docs/`
folder. It is meant to be read **and** run: start a project, break it on
purpose, and watch the tooling detect and recover from the problem.

## How the projects connect

```
 1 Linux Ops Toolkit ──▶ 2 Docker three-tier ──▶ 3 Ansible provisioning ──▶ 4 Observability ──▶ 5 PayFlow CI/CD
   Bash, systemd,          images, compose,        VMs, roles, rolling       metrics, logs,      pipelines, scanning,
   networking, logs        networks, secrets       updates, hardening        alerts, Zabbix      canary, Kubernetes
                                                                                                 (uses ideas from 1-4)
```

Project 5 is the capstone: it reuses the shell scripting of project 1,
the container design of project 2, the Ansible deployment of project 3 and
the Prometheus/Grafana monitoring of project 4.

## Project details

### Linux Ops Toolkit ([`01-linux-ops-toolkit/`](01-linux-ops-toolkit/))

Production-style Bash commands for day-to-day server administration:

| Script | What it does |
|---|---|
| `sysreport.sh` | CPU load, memory, disks, listening ports, failed systemd units (text or `--json`) |
| `netcheck.sh` | Layered DNS → TCP → HTTP checks with latency |
| `backup.sh` | `tar.gz` backups with SHA-256 verification and retention |
| `logwatch.sh` | Nginx access log and SSH auth log summaries (5xx ratio, brute force) |
| `service_watchdog.sh` | Restarts a failed service with a restart rate limit and alerts |
| `user_audit.sh` | Finds extra UID 0 accounts, sudoers, empty passwords |

Scripts return meaningful exit codes, send webhook alerts (Slack/Teams),
are scheduled with systemd timers or cron, linted with ShellCheck and
covered by 18 Bats tests. **Linux only** for real use.

### TaskBoard: Docker three-tier app ([`02-docker-three-tier-app/`](02-docker-three-tier-app/))

A small task board web app built to show how containers are packaged,
connected and operated:

* **web**: Nginx serves the static UI and reverse-proxies `/api`.
* **api**: Flask + SQLAlchemy on Gunicorn, multi-stage image, non-root user.
* **db**: PostgreSQL 16 on an `internal` network (not reachable from the host).

It uses Docker secrets for the DB password, healthcheck-based startup
ordering, CPU/memory limits, `--scale api=3` load balancing, `pg_dump`
backup/restore, pytest unit tests and an end-to-end test script.

### Ansible infrastructure provisioning ([`03-ansible-infra-provisioning/`](03-ansible-infra-provisioning/))

Infrastructure as Code for a small on-prem web tier: **lb01** (Nginx load
balancer) and **web01/web02** (app servers) as VirtualBox VMs created by
Vagrant and configured entirely by Ansible roles:

* `common`: users, SSH hardening, UFW firewall, sysctl, chrony, unattended upgrades.
* `node_exporter`: Prometheus host metrics agent.
* `webapp`: the demo service as a sandboxed systemd unit.
* `nginx_lb`: upstream pool generated from the inventory, validated with `nginx -t`.

Playbooks cover full provisioning, **zero-downtime rolling updates**
(drain → deploy → verify → undrain, one server at a time), OS patching
and a fleet health report. An offline test suite runs 15 checks without VMs.

### Observability stack ([`04-observability-stack/`](04-observability-stack/))

A complete monitoring and alerting platform in Docker Compose:

* **Metrics**: Prometheus scraping a demo app, node-exporter, cAdvisor and Blackbox probes.
* **Logs**: Promtail ships container logs to Loki.
* **Dashboards**: three Grafana dashboards provisioned as code.
* **Alerts**: 11 alert rules routed by Alertmanager with grouping and inhibition.
* **Zabbix** (optional profile): server, agent and API-based host registration.

`chaos.sh` injects errors, latency or downtime into the demo app so you
can watch alerts fire and resolve. Alert rules have unit tests (promtool)
and a live pipeline test.

### PayFlow DevOps pipeline ([`05-payflow-devops-pipeline/`](05-payflow-devops-pipeline/))

An end-to-end delivery system for a fintech-style transaction API:

**git push → CI (Jenkins / TeamCity / Bitbucket / GitHub Actions) → lint and
tests → Docker image → Trivy scan → private registry → manual approval →
Ansible deploy with canary and automatic rollback → smoke test →
Prometheus/Grafana monitoring**, and the same image deploys to
**Kubernetes (kind)** with rolling updates, probes, HPA and `rollout undo`.

A local **CI lab** (Jenkins configured as code, TeamCity server + agent,
Gitea Git server, Docker registry) lets you run the pipelines for real.

## Tools and technologies required

### Automatic installation: `install.sh`

You don't have to install the tools below by hand. **`install.sh`** (in
the repository root) detects your system and installs everything the
projects need:

```bash
./install.sh --dry-run       # 1. preview: shows what it would install, changes nothing
./install.sh                 # 2. install for all projects
./install.sh 02 04           #    ...or only for some projects
./run.sh doctor              # 3. confirm every project is ready
```

| Your system | How it installs |
|---|---|
| macOS (Intel or Apple Silicon) | Homebrew (installed first if missing): formulae + Docker Desktop cask |
| Ubuntu / Debian / WSL2 | `apt` packages + `docker.io` and Compose v2 |
| Fedora / RHEL / Rocky / Alma | `dnf` packages + Docker CE repository |
| Arch Linux | `pacman` packages |

What it sets up:

1. **System tools**: Docker + Compose, ShellCheck, Bats, hadolint, kind, kubectl,
   Prometheus/Alertmanager tools (`promtool`, `amtool`), Vagrant/VirtualBox where supported.
   On Linux, single binaries go to `~/.local/bin`.
2. **Python**: one shared virtualenv at `./.venv` (native Python 3.10-3.12) with
   pytest, ruff, yamllint, ansible, ansible-lint and every project's requirements.
3. **Ansible collections** for projects 3 and 5.
4. **Docker**: starts Docker Desktop / the Docker service.

Every `run.sh` automatically uses `./.venv` and `~/.local/bin`, so there is
nothing to activate. Inside a project folder, `./run.sh install-deps` does
the same for just that project. Skipped items (for example VMs on Apple
Silicon) are listed in a **Notes** section at the end of the run.

### Manual installation

If you prefer to install by hand, install only what the project you want
to run needs. Each `run.sh` has a `doctor` command that checks this for you.

### Needed by every project

| Tool | Version | Why |
|---|---|---|
| Git | any recent | clone the repository |
| Bash | 4+ recommended (macOS ships 3.2; `run.sh` works with it) | all scripts |
| curl | any | health checks and tests |
| make | optional | every project also has a `Makefile`; `run.sh` does not need it |

### Per project

| Tool / technology | 1 Linux | 2 Docker | 3 Ansible | 4 Observability | 5 PayFlow |
|---|:-:|:-:|:-:|:-:|:-:|
| Linux (Ubuntu 22.04/24.04) | **required** | | VMs are Ubuntu | | for VM deploys |
| systemd, coreutils, iproute2 (`ss`), `getent` | **required** | | | | |
| Docker Engine 24+ / Docker Desktop | | **required** | | **required** | **required** |
| Docker Compose v2 (`docker compose`) | | **required** | | **required** | **required** |
| Python 3.10+ (3.12 used in images) | | tests | **required** | tests | **required** |
| VirtualBox 7+ | | | **required** | | optional |
| Vagrant 2.3+ | | | **required** | | optional |
| Ansible 2.15+ (`ansible`, `ansible-galaxy`) | | | **required** | | deploy |
| kind + kubectl | | | | | Kubernetes part |
| Trivy (runs as a Docker image) | | | | | scan |
| Prometheus / Alertmanager binaries (`promtool`, `amtool`) | | | | validate / live test | |

### Quality and test tools (optional, for `lint` / `test`)

| Tool | Used in | Install |
|---|---|---|
| ShellCheck | 1, 2, 5 | `brew install shellcheck` / `apt install shellcheck` |
| Bats | 1 | `brew install bats-core` / `apt install bats` |
| pytest, ruff | 2, 4, 5 | `pip install pytest ruff` (project 5: `./run.sh setup`) |
| hadolint | 2 | `brew install hadolint` |
| ansible-lint, yamllint | 3, 4, 5 | `pip install ansible-lint yamllint` |

### Hardware

| Project | RAM (free) | Notes |
|---|---|---|
| 1 | minimal | |
| 2 | ~1 GB | |
| 3 | ~1.5 GB | three 512 MB VMs; VirtualBox x86 box: **not on Apple Silicon** |
| 4 | ~3 GB (~4.5 GB with Zabbix) | |
| 5 | ~2 GB; ~6 GB with the CI lab | Jenkins + TeamCity are heavy |

### Technologies covered

Linux · Bash · systemd · cron · networking (DNS/TCP/HTTP) · Docker ·
Docker Compose · Nginx · Python · Flask · Gunicorn · SQLAlchemy ·
PostgreSQL · Ansible · Jinja2 · Vagrant · VirtualBox · Prometheus ·
PromQL · Alertmanager · Grafana · Loki · Promtail · Blackbox exporter ·
cAdvisor · node_exporter · Zabbix · Jenkins (JCasC, Job DSL) · TeamCity
(Kotlin DSL) · Bitbucket Pipelines · GitHub Actions · Gitea · Docker
registry · Trivy · Kubernetes · kind · kustomize · ShellCheck · Bats ·
pytest · ruff · hadolint · ansible-lint · yamllint.

## How to use: the run.sh scripts

Every project folder has an executable **`run.sh`**, and there is one more
at the root that forwards to them.

| File | Purpose |
|---|---|
| [`run.sh`](run.sh) | Root launcher: lists projects, forwards commands, runs `doctor` for all |
| [`01-linux-ops-toolkit/run.sh`](01-linux-ops-toolkit/run.sh) | lint, test, demo, run each tool, install with systemd timers |
| [`02-docker-three-tier-app/run.sh`](02-docker-three-tier-app/run.sh) | start/stop the stack, e2e test, scale, backup/restore, Adminer |
| [`03-ansible-infra-provisioning/run.sh`](03-ansible-infra-provisioning/run.sh) | create VMs, provision, rolling update, patch, report, offline tests |
| [`04-observability-stack/run.sh`](04-observability-stack/run.sh) | start the stack (with or without Zabbix), chaos scenarios, rule tests |
| [`05-payflow-devops-pipeline/run.sh`](05-payflow-devops-pipeline/run.sh) | venv setup, tests, Docker stack, smoke test, kind deploy, CI lab |

What each `run.sh` does:

* `./run.sh` or `./run.sh help` lists every command.
* `./run.sh doctor` checks the required tools and tells you what is missing.
* It always runs from its own folder, so you can call it from anywhere.
* It checks that the needed tools (and the Docker daemon) are available
  before running a command, and prints a clear error if not.
* Destructive commands (`nuke`) ask for confirmation.
* It does **not** need `make`; the `Makefile` targets still work if you prefer them.

### From the repository root

```bash
./run.sh                         # list the projects
./run.sh doctor                  # check tools for every project
./run.sh 02 start                # same as: cd 02-docker-three-tier-app && ./run.sh start
./run.sh observability chaos errors 0.3   # projects can also be named by part of the folder name
```

### Inside a project folder

```bash
cd 02-docker-three-tier-app
./run.sh help
./run.sh doctor
./run.sh start
```

If a script is not executable after cloning or unzipping, run
`chmod +x run.sh */run.sh`.

## Quick start per project

First, once: `./install.sh` (see [Automatic installation](#automatic-installation-installsh)).

### Linux Ops Toolkit (Linux)

```bash
cd 01-linux-ops-toolkit
./run.sh doctor
./run.sh check                   # shellcheck + 18 Bats tests
./run.sh demo                    # sysreport, netcheck, logwatch on sample data
./run.sh install-timers          # optional: install system-wide with systemd timers

# on macOS / Windows (runs in an Ubuntu Docker container):
./run.sh test-linux
./run.sh demo-linux
```

### TaskBoard (Docker)

```bash
cd 02-docker-three-tier-app
./run.sh start                   # open http://localhost:8080
./run.sh e2e                     # end-to-end test
./run.sh scale 3                 # 3 API replicas behind nginx
./run.sh backup
./run.sh stop
```

### Ansible lab (VirtualBox + Vagrant)

```bash
cd 03-ansible-infra-provisioning
./run.sh all                     # collections + VMs + ping + provision
./run.sh traffic                 # requests alternate between web01 and web02
./run.sh rolling 1.2.0           # zero-downtime release (run traffic in another terminal)
./run.sh destroy

# Apple Silicon / no VirtualBox: run the 15 offline checks in a Linux container
./run.sh test-linux
```

### Observability stack (Docker)

```bash
cd 04-observability-stack
./run.sh start                   # Grafana http://localhost:3000 (admin/admin)
./run.sh chaos errors 0.3        # HighErrorRate fires in ~3 minutes
./run.sh chaos reset
./run.sh stop
```

### PayFlow pipeline (Python + Docker, optional kind)

```bash
cd 05-payflow-devops-pipeline
./run.sh setup                   # .venv with dev dependencies
./run.sh lint && ./run.sh test
./run.sh start && ./run.sh smoke # API via nginx on :8080
./run.sh k8s                     # optional: deploy to a local kind cluster
./run.sh ci-lab-up               # optional: Jenkins, TeamCity, Gitea, registry
```

## Ports used

Projects 2, 4 and 5 share some ports (8080, 3000, 9090, 8081), so **run
one Docker project at a time** (stop one with `./run.sh stop` before
starting another).

| Port | Project | Service |
|---|---|---|
| 8080 | 2 | TaskBoard (nginx) |
| 8081 | 2 / 4 | Adminer / Zabbix web |
| 8080 | 3 | lb01 load balancer (forwarded from the VM) |
| 3000, 9090, 9093, 9095, 3100, 8000 | 4 | Grafana, Prometheus, Alertmanager, alert receiver, Loki, demo app |
| 8080, 9090, 3000 | 5 | PayFlow API (nginx), Prometheus, Grafana |
| 8090, 8111, 3001, 5000 | 5 (CI lab) | Jenkins, TeamCity, Gitea, registry |

## Repository layout

```
devops-portfolio/
├── README.md                         # this file
├── install.sh                        # detects the OS and installs every dependency
├── run.sh                            # root launcher
├── .venv/                            # created by install.sh (shared Python tools, git-ignored)
├── 01-linux-ops-toolkit/             # Bash + systemd       (run.sh, README.md, docs/)
├── 02-docker-three-tier-app/         # Docker Compose app   (run.sh, README.md, docs/)
├── 03-ansible-infra-provisioning/    # Ansible + Vagrant    (run.sh, README.md, docs/)
├── 04-observability-stack/           # monitoring/alerting  (run.sh, README.md, docs/)
└── 05-payflow-devops-pipeline/       # CI/CD + Kubernetes   (run.sh, README.md, docs/)
```

Each project README has the full architecture, features, test details and
links to its `docs/` folder.

## Troubleshooting

| Problem | Fix |
|---|---|
| `permission denied: ./run.sh` | `chmod +x run.sh */run.sh` |
| `Docker daemon is not running` | start Docker Desktop (macOS/Windows) or `sudo systemctl start docker` |
| `port is already allocated` | another project is running; `./run.sh stop` in that folder |
| `missing tool(s): ...` | run `./install.sh` (or `./run.sh install-deps` inside the project) |
| Project 1 fails on macOS | it targets Linux; use `./run.sh test-linux` / `./run.sh demo-linux` (runs in Docker) |
| Project 3 VMs fail on Apple Silicon | the VirtualBox box is x86-only; use an Intel Mac or Linux host. `./run.sh test-linux` runs the offline tests in Docker |
| On Linux, `docker: permission denied` after install | log out and back in (or `newgrp docker`) so the new `docker` group applies |
| Grafana shows no data | wait 1-2 minutes after `start`; check `./run.sh status` |

---

**Author:** Basil Ahtisham · [LinkedIn](https://linkedin.com/in/mianbasil) · [GitHub](https://github.com/Mian-Basam)

---

<div align="center">

**Built by [Mian Basam Ahmad](https://github.com/Mian-Basam)** · Software Engineer & Tech Lead

[![Blog](https://img.shields.io/badge/Blog-mian--basam.github.io-222222?style=flat-square&logo=githubpages&logoColor=white)](https://mian-basam.github.io) [![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/mian-basam-ahmad-68b997147/) [![GitHub](https://img.shields.io/badge/GitHub-Mian--Basam-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/Mian-Basam)

<sub>If this project helped you, consider giving it a ⭐</sub>

</div>
