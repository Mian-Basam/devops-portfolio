#!/usr/bin/env bash
# Ansible Infrastructure Provisioning Lab - one entry point for every common task.
#
#   ./run.sh                 show help
#   ./run.sh all             deps + create VMs + ping + provision (full lab build)
#   ./run.sh traffic         watch the load balancer alternate between web01/web02
#   ./run.sh destroy         delete the VMs
#
# Run "./run.sh help" for the full list.
# Target another inventory with:  INV=inventories/production/hosts.ini ./run.sh provision
set -euo pipefail
cd "$(dirname "$0")"

# Use tools installed by ../install.sh (shared ../.venv and ~/.local/bin); nothing to activate.
[[ -x ../.venv/bin/python ]] && PATH="$(cd .. && pwd)/.venv/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"; export PATH

INV="${INV:-inventories/vagrant/hosts.ini}"

c_ok=$'\e[32m'; c_err=$'\e[31m'; c_dim=$'\e[2m'; c_off=$'\e[0m'
[[ -t 1 && -z "${NO_COLOR:-}" ]] || { c_ok=""; c_err=""; c_dim=""; c_off=""; }
say()  { printf '%s>>%s %s\n' "$c_ok" "$c_off" "$*"; }
die()  { printf '%sERROR:%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }
need() { local m=(); for t in "$@"; do command -v "$t" >/dev/null || m+=("$t"); done
         ((${#m[@]} == 0)) || die "missing tool(s): ${m[*]}  (fix: ./run.sh install-deps)"; }
play() { need ansible-playbook; say "ansible-playbook -i $INV $*"; ansible-playbook -i "$INV" "$@"; }

doctor() {
  local rc=0
  for t in vagrant VBoxManage python3 ansible ansible-playbook ansible-galaxy ansible-lint yamllint curl; do
    if command -v "$t" >/dev/null; then printf '  %sok%s       %s\n' "$c_ok" "$c_off" "$t"
    else printf '  %smissing%s  %s\n' "$c_err" "$c_off" "$t"; rc=1; fi
  done
  if [[ "$(uname -m)" == "arm64" && "$(uname -s)" == "Darwin" ]]; then
    printf '\n%sNote:%s Apple Silicon: the ubuntu/jammy64 box is x86-only. VirtualBox VMs will not run here;\n' "$c_err" "$c_off"
    printf '      use an Intel/Linux host. Here, run the offline tests with: ./run.sh test-linux (needs Docker)\n'
  fi
  printf '\n%sInstall everything automatically: ./run.sh install-deps   (or ../install.sh 03)%s\n' "$c_dim" "$c_off"
  return $rc
}

# Run the offline test suite inside an Ubuntu container (GNU tools + nginx), e.g. on macOS.
test_linux() {
  command -v docker >/dev/null || die "Docker is needed for test-linux"
  docker info >/dev/null 2>&1 || die "Docker is not running - start Docker Desktop first"
  say "running the offline test suite inside an Ubuntu 24.04 container (first run ~2-3 min)"
  docker run --rm -t -v "$PWD":/work -w /work -e ANSIBLE_CONFIG=/work/ansible.cfg ubuntu:24.04 bash -c '
    set -e
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-venv nginx curl git >/dev/null
    python3 -m venv /opt/venv && /opt/venv/bin/pip install -q ansible ansible-lint yamllint
    export PATH=/opt/venv/bin:$PATH
    ansible-galaxy collection install -r requirements.yml >/dev/null
    ./tests/run_tests.sh'
}

usage() {
  cat <<EOF
Ansible Infrastructure Provisioning Lab - run.sh

Usage: ./run.sh <command> [args]        (inventory: $INV)

Setup
  install-deps         install every dependency for this project (../install.sh 03)
  doctor               check required tools
  deps                 install Ansible collections (requirements.yml)
  all                  deps + up + ping + provision  (full lab in one go)

Virtual machines (Vagrant + VirtualBox)
  up                   create/start lb01, web01, web02
  status               vagrant status
  ssh <host>           ssh into a VM, e.g. ./run.sh ssh web01
  down                 stop the VMs
  destroy              delete the VMs

Ansible
  ping                 check Ansible reaches every host
  provision            run the full site playbook (idempotent)
  dry-run              show what would change (--check --diff)
  rolling [version]    zero-downtime release (default 1.1.0)
  patch                OS patching, one host at a time
  report               fleet health report

Try it
  traffic              curl the load balancer in a loop (Ctrl-C to stop)

Quality
  lint                 ansible-lint + yamllint
  test                 offline test suite (no VMs; Linux recommended)
  test-linux           offline test suite inside an Ubuntu Docker container (works on macOS)
EOF
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  help|-h|--help) usage ;;
  install-deps)
    [[ -x ../install.sh ]] || die "../install.sh not found: it is in the full portfolio repo (git clone https://github.com/Mian-Basam/devops-portfolio)"
    exec ../install.sh 03 "$@" ;;
  doctor)    doctor ;;
  deps)      need ansible-galaxy; ansible-galaxy collection install -r requirements.yml ;;
  up)        need vagrant; vagrant up ;;
  status)    need vagrant; vagrant status ;;
  ssh)       need vagrant; vagrant ssh "${1:?usage: ./run.sh ssh <lb01|web01|web02>}" ;;
  down)      need vagrant; vagrant halt ;;
  destroy)   need vagrant; vagrant destroy -f ;;
  ping)      need ansible; ansible -i "$INV" all -m ping ;;
  provision) play playbooks/site.yml ;;
  dry-run)   play playbooks/site.yml --check --diff ;;
  rolling)   play playbooks/rolling_update.yml -e "webapp_version=${1:-1.1.0}" ;;
  patch)     play playbooks/patch.yml ;;
  report)    play playbooks/health_report.yml ;;
  all)
    "$0" deps && "$0" up && "$0" ping && "$0" provision
    say "lab ready - try: ./run.sh traffic" ;;
  traffic)
    need curl; say "hitting http://localhost:8080/ every 0.5s (Ctrl-C to stop)"
    while true; do curl -s --max-time 2 localhost:8080/ || printf 'no response'; echo; sleep 0.5; done ;;
  lint)      need ansible-lint yamllint; ansible-lint && yamllint -c .yamllint.yml . && say "lint passed" ;;
  test)      need ansible-lint yamllint ansible-playbook python3 curl; ./tests/run_tests.sh ;;
  test-linux) test_linux ;;
  *)         usage; die "unknown command: $cmd" ;;
esac
