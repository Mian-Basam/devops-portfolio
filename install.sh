#!/usr/bin/env bash
# install.sh - detect this machine and install every dependency the portfolio needs.
#
#   ./install.sh                 install for ALL projects
#   ./install.sh 02 04           install only for projects 02 and 04
#   ./install.sh --dry-run       show what would be installed, change nothing
#   ./install.sh --yes           don't ask for confirmation
#
# Supported: macOS (Homebrew), Debian/Ubuntu/WSL (apt), Fedora/RHEL/Rocky/Alma (dnf), Arch (pacman).
#
# What it does
#   1. system packages   docker, shellcheck, bats, hadolint, kind, kubectl, prometheus tools, ...
#   2. Python            a shared virtualenv at ./.venv (Python 3.10-3.12) with pytest, ruff,
#                        yamllint, ansible, ansible-lint and each project's requirements
#   3. Ansible           the collections that projects 03 and 05 use
#   4. Docker            starts the Docker daemon / Docker Desktop
# Every run.sh automatically uses ./.venv and ~/.local/bin, nothing to activate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# ----------------------------------------------------------------- versions
HADOLINT_V=2.12.0; KIND_V=0.24.0; KUBECTL_V=1.31.0; PROM_V=2.54.1; AM_V=0.27.0
VENV="$ROOT/.venv"; LOCAL_BIN="$HOME/.local/bin"

# ----------------------------------------------------------------- output
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
else B=""; G=""; Y=""; R=""; D=""; N=""; fi
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %sok%s    %s\n' "$G" "$N" "$*"; }
info() { printf '  %s..%s    %s\n' "$D" "$N" "$*"; }
warn() { printf '  %s!!%s    %s\n' "$Y" "$N" "$*"; WARNINGS+=("$*"); }
die()  { printf '%sERROR:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
WARNINGS=()

# ----------------------------------------------------------------- args
DRY=0; YES=0; SEL=()
usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; }
for a in "$@"; do
  case "$a" in
    -n|--dry-run) DRY=1 ;;
    -y|--yes)     YES=1 ;;
    -h|--help)    usage; exit 0 ;;
    all)          SEL=(01 02 03 04 05) ;;
    1|01|*linux*)                  SEL+=(01) ;;
    2|02|*docker*|*taskboard*)     SEL+=(02) ;;
    3|03|*ansible*)                SEL+=(03) ;;
    4|04|*observ*|*monitor*)       SEL+=(04) ;;
    5|05|*payflow*|*pipeline*)     SEL+=(05) ;;
    *) usage; die "unknown argument: $a" ;;
  esac
done
((${#SEL[@]})) || SEL=(01 02 03 04 05)
has() { case " ${SEL[*]} " in *" $1 "*) return 0 ;; esac; return 1; }
any() { local p; for p in "$@"; do has "$p" && return 0; done; return 1; }

# run a command, or just print it in dry-run mode
run() { if ((DRY)); then printf '  %s[dry-run]%s %s\n' "$D" "$N" "$*"; else "$@"; fi; }
cmd_ok() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------- detect
OS="$(uname -s)"; ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in x86_64|amd64) ARCH=amd64 ;; arm64|aarch64) ARCH=arm64 ;; *) ARCH="$ARCH_RAW" ;; esac
PM=""; DISTRO=""; DISTRO_LIKE=""; WSL=0
case "$OS" in
  Darwin) PM=brew; DISTRO="macOS $(sw_vers -productVersion 2>/dev/null || true)" ;;
  Linux)
    # shellcheck disable=SC1091
    [[ -r /etc/os-release ]] && . /etc/os-release
    DISTRO="${PRETTY_NAME:-Linux}"; DISTRO_LIKE="${ID:-} ${ID_LIKE:-}"
    grep -qi microsoft /proc/version 2>/dev/null && WSL=1
    if   cmd_ok apt-get; then PM=apt
    elif cmd_ok dnf;     then PM=dnf
    elif cmd_ok pacman;  then PM=pacman
    else die "unsupported Linux distribution ($DISTRO): need apt, dnf or pacman"; fi ;;
  *) die "unsupported OS: $OS (use macOS, Linux or WSL2 on Windows)" ;;
esac

SUDO=""
if [[ "$OS" == Linux && $EUID -ne 0 ]]; then
  cmd_ok sudo || die "sudo is required to install system packages"
  SUDO=sudo
fi

# What the selected projects need
NEED_DOCKER=0; NEED_PY=0; NEED_VMS=0; NEED_K8S=0; NEED_PROM=0
NEED_SHELLCHECK=0; NEED_BATS=0; NEED_HADOLINT=0; NEED_ANSIBLE=0
any 02 04 05 && NEED_DOCKER=1
any 02 03 04 05 && NEED_PY=1
any 03 05 && NEED_ANSIBLE=1
any 03 && NEED_VMS=1
has 05 && NEED_K8S=1
has 04 && NEED_PROM=1
any 01 02 05 && NEED_SHELLCHECK=1
has 01 && NEED_BATS=1
has 02 && NEED_HADOLINT=1

VM_SUPPORTED=1
[[ "$ARCH" == arm64 ]] && VM_SUPPORTED=0   # ubuntu/jammy64 Vagrant box is x86-only
((WSL)) && VM_SUPPORTED=0                  # VirtualBox belongs on the Windows side

step "System"
info "OS        : $DISTRO ($ARCH)$( ((WSL)) && echo ', WSL')"
info "Installer : $PM"
info "Projects  : ${SEL[*]}"
((DRY)) && info "Mode      : dry run (nothing will be changed)"

if ((!YES && !DRY)) && [[ -t 0 ]]; then
  printf '\nInstall the dependencies for projects %s? [Y/n] ' "${SEL[*]}"
  read -r ans; [[ -z "$ans" || "$ans" =~ ^[Yy] ]] || die "aborted"
fi

# ----------------------------------------------------------------- helpers
# collect package names for tools that are missing:  want <command> <package>
PKGS=()
want() { if cmd_ok "$1"; then ok "$1 already installed"; else PKGS+=("$2"); fi; }

# download a single binary into ~/.local/bin (Linux)
fetch_bin() { # name url
  cmd_ok "$1" && { ok "$1 already installed"; return; }
  info "downloading $1"
  run mkdir -p "$LOCAL_BIN"
  run curl -fsSL -o "$LOCAL_BIN/$1" "$2"
  run chmod +x "$LOCAL_BIN/$1"
}
# download a release tarball and copy some of its binaries into ~/.local/bin (Linux)
fetch_tar() { # url dir-inside-tar bin...
  local url="$1" dir="$2"; shift 2
  local missing=0 b; for b in "$@"; do cmd_ok "$b" || missing=1; done
  ((missing)) || { ok "$* already installed"; return; }
  info "downloading $*"
  if ((DRY)); then run curl -fsSL "$url" "| tar -xz -> $LOCAL_BIN/{$*}"; return; fi
  local t; t="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz -C "$t"
  mkdir -p "$LOCAL_BIN"
  for b in "$@"; do install -m 0755 "$t/$dir/$b" "$LOCAL_BIN/$b"; done
  rm -rf "$t"
}

# Best Python 3.10-3.12 built for this CPU (an x86 Python under Rosetta is skipped on Apple
# Silicon). 3.12 first: every pinned wheel (e.g. psycopg2-binary 2.9.9) exists for it.
# "pick_python any" also accepts newer versions as a last resort.
pick_python() {
  local c p v m list="python3.12 python3.11 python3.10"
  [[ "${1:-}" == any ]] && list="$list python3.13 python3"
  for c in $list; do
    for p in "/opt/homebrew/bin/$c" "/usr/local/bin/$c" "/usr/bin/$c" "$c"; do
      cmd_ok "$p" || continue
      v=$("$p" -c 'import sys; print("%d%02d" % sys.version_info[:2])' 2>/dev/null) || continue
      m=$("$p" -c 'import platform; print(platform.machine())' 2>/dev/null) || continue
      [[ "$m" == "$ARCH_RAW" || ( "$m" == x86_64 && "$ARCH" == amd64 ) || ( "$m" == aarch64 && "$ARCH" == arm64 ) ]] || continue
      if ((v >= 310)); then command -v "$p"; return 0; fi
    done
  done
  return 1
}

# ----------------------------------------------------------------- macOS
install_macos() {
  step "Homebrew"
  if ! cmd_ok brew; then
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $p ]] && eval "$("$p" shellenv)"; done
  fi
  if ! cmd_ok brew; then
    warn "Homebrew not found - installing it (official installer from brew.sh)"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ((DRY)) || { for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $p ]] && eval "$("$p" shellenv)"; done; }
  else ok "brew $(brew --version | head -1 | awk '{print $2}')"; fi

  step "Command-line tools"
  PKGS=()
  want git git; want curl curl
  ((NEED_SHELLCHECK)) && want shellcheck shellcheck
  ((NEED_BATS))       && want bats bats-core
  ((NEED_HADOLINT))   && want hadolint hadolint
  ((NEED_K8S))        && { want kind kind; want kubectl kubernetes-cli; }
  ((NEED_PROM))       && { want promtool prometheus; want amtool alertmanager; }
  has 01 && want gsha256sum coreutils          # GNU tools for local experiments
  if ((NEED_PY)) && ! pick_python >/dev/null; then PKGS+=(python@3.12); fi
  if ((${#PKGS[@]})); then run brew install "${PKGS[@]}"; fi

  if ((NEED_DOCKER)); then
    step "Docker"
    if cmd_ok docker || [[ -d /Applications/Docker.app ]]; then ok "Docker Desktop installed"
    else run brew install --cask docker; fi
  fi

  if ((NEED_VMS)); then
    step "Virtual machines (project 03)"
    if ((VM_SUPPORTED)); then
      cmd_ok vagrant    && ok "vagrant installed"    || run brew install --cask vagrant
      cmd_ok VBoxManage && ok "VirtualBox installed" || run brew install --cask virtualbox
    else
      warn "Apple Silicon: the project 03 VMs (x86 ubuntu/jammy64 + VirtualBox) can't run here. Skipped Vagrant/VirtualBox. Use: cd 03-ansible-infra-provisioning && ./run.sh test-linux"
    fi
  fi
}

# ----------------------------------------------------------------- Linux
install_linux_packages() {
  step "System packages ($PM)"
  PKGS=()
  case "$PM" in
    apt)
      run $SUDO apt-get update -qq
      PKGS=(ca-certificates curl git make tar gzip iproute2 procps python3 python3-venv python3-pip)
      ((NEED_SHELLCHECK)) && PKGS+=(shellcheck)
      ((NEED_BATS)) && PKGS+=(bats)
      run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${PKGS[@]}" ;;
    dnf)
      case " $DISTRO_LIKE " in *" rhel "*|*" centos "*) run $SUDO dnf install -y epel-release || warn "could not enable EPEL" ;; esac
      PKGS=(ca-certificates curl git make tar gzip iproute procps-ng python3 python3-pip)
      ((NEED_SHELLCHECK)) && PKGS+=(ShellCheck)
      ((NEED_BATS)) && PKGS+=(bats)
      run $SUDO dnf install -y "${PKGS[@]}" ;;
    pacman)
      PKGS=(ca-certificates curl git make tar gzip iproute2 procps-ng python python-pip)
      ((NEED_SHELLCHECK)) && PKGS+=(shellcheck)
      ((NEED_BATS)) && PKGS+=(bash-bats)
      run $SUDO pacman -Sy --needed --noconfirm "${PKGS[@]}" ;;
  esac

  if ((NEED_PY)) && ! pick_python >/dev/null; then
    warn "no Python >= 3.10 found; trying to install one"
    case "$PM" in
      apt)    run $SUDO apt-get install -y -qq python3.11 python3.11-venv || run $SUDO apt-get install -y -qq python3.12 python3.12-venv || true ;;
      dnf)    run $SUDO dnf install -y python3.12 || run $SUDO dnf install -y python3.11 || true ;;
      pacman) : ;;  # Arch python is always recent
    esac
  fi
}

install_linux_docker() {
  ((NEED_DOCKER)) || return 0
  step "Docker"
  if cmd_ok docker && docker compose version >/dev/null 2>&1; then
    ok "docker + compose already installed"
  elif ((WSL)) && ! cmd_ok docker; then
    warn "WSL: install Docker Desktop on Windows and enable 'WSL integration' for this distro (docs.docker.com/desktop/wsl)"
    return 0
  else
    case "$PM" in
      apt)
        run $SUDO apt-get install -y -qq docker.io
        run $SUDO apt-get install -y -qq docker-compose-v2 2>/dev/null \
          || run $SUDO apt-get install -y -qq docker-compose-plugin 2>/dev/null \
          || warn "Compose v2 package not found in this distro; see docs.docker.com/engine/install" ;;
      dnf)
        local repo=fedora; case " $DISTRO_LIKE " in *" rhel "*|*" centos "*) repo=centos ;; esac
        run bash -c "curl -fsSL https://download.docker.com/linux/$repo/docker-ce.repo | $SUDO tee /etc/yum.repos.d/docker-ce.repo >/dev/null"
        run $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin ;;
      pacman)
        run $SUDO pacman -S --needed --noconfirm docker docker-compose ;;
    esac
  fi
  if cmd_ok systemctl && [[ -d /run/systemd/system ]]; then
    run $SUDO systemctl enable --now docker
  fi
  if [[ $EUID -ne 0 ]] && ! id -nG "$USER" | grep -qw docker; then
    run $SUDO usermod -aG docker "$USER"
    warn "added $USER to the 'docker' group: log out and back in (or run 'newgrp docker') before using Docker"
  fi
}

install_linux_binaries() {
  local hl_arch kind_arch
  [[ "$ARCH" == amd64 ]] && hl_arch=x86_64 || hl_arch=arm64
  kind_arch=$ARCH
  if ((NEED_HADOLINT)); then step "hadolint"; fetch_bin hadolint "https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_V/hadolint-Linux-$hl_arch"; fi
  if ((NEED_K8S)); then
    step "kind + kubectl"
    fetch_bin kind    "https://kind.sigs.k8s.io/dl/v$KIND_V/kind-linux-$kind_arch"
    fetch_bin kubectl "https://dl.k8s.io/release/v$KUBECTL_V/bin/linux/$ARCH/kubectl"
  fi
  if ((NEED_PROM)); then
    step "Prometheus + Alertmanager tools"
    fetch_tar "https://github.com/prometheus/prometheus/releases/download/v$PROM_V/prometheus-$PROM_V.linux-$ARCH.tar.gz" \
      "prometheus-$PROM_V.linux-$ARCH" prometheus promtool
    fetch_tar "https://github.com/prometheus/alertmanager/releases/download/v$AM_V/alertmanager-$AM_V.linux-$ARCH.tar.gz" \
      "alertmanager-$AM_V.linux-$ARCH" alertmanager amtool
  fi
  if ((NEED_VMS)); then
    step "Virtual machines (project 03)"
    if ((!VM_SUPPORTED)); then
      warn "VirtualBox VMs are not supported on $ARCH$( ((WSL)) && echo '/WSL'); skipped. Offline tests still work: cd 03-ansible-infra-provisioning && ./run.sh test"
    else
      cmd_ok VBoxManage && ok "VirtualBox installed" || case "$PM" in
        apt) run $SUDO apt-get install -y -qq virtualbox || warn "install VirtualBox from virtualbox.org" ;;
        pacman) run $SUDO pacman -S --needed --noconfirm virtualbox || warn "install VirtualBox from virtualbox.org" ;;
        *) warn "install VirtualBox 7+ from virtualbox.org" ;;
      esac
      cmd_ok vagrant && ok "vagrant installed" || case "$PM" in
        apt) run $SUDO apt-get install -y -qq vagrant || warn "install Vagrant from developer.hashicorp.com/vagrant/install" ;;
        *) warn "install Vagrant from developer.hashicorp.com/vagrant/install" ;;
      esac
    fi
  fi
}

# ----------------------------------------------------------------- Python venv
install_python() {
  ((NEED_PY)) || return 0
  step "Python virtualenv ($VENV)"
  local py
  if ((DRY)) && ! pick_python >/dev/null; then py="python3.12"
  else py="$(pick_python || pick_python any)" || die "Python 3.10+ is required but could not be installed"; fi
  if [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" -c 'import sys; sys.exit(sys.version_info < (3,10))' 2>/dev/null; then
    ok "existing venv: $("$VENV/bin/python" --version)"
  else
    [[ -d "$VENV" ]] && run rm -rf "$VENV"
    info "creating venv with $py ($("$py" --version 2>/dev/null || echo "$py"))"
    run "$py" -m venv "$VENV"
  fi
  local pip="$VENV/bin/pip" reqs=() extra=()
  has 02 && reqs+=(-r 02-docker-three-tier-app/api/requirements-dev.txt)
  has 04 && { reqs+=(-r 04-observability-stack/demo-app/requirements.txt); extra+=(pytest==8.3.3 ruff==0.6.9 yamllint); }
  has 05 && { reqs+=(-r 05-payflow-devops-pipeline/requirements-dev.txt); extra+=(yamllint); }
  ((NEED_ANSIBLE)) && extra+=(ansible ansible-lint yamllint)
  run "$pip" install -q --upgrade pip
  info "installing: ${reqs[*]+${reqs[*]}} ${extra[*]+${extra[*]}}"
  run "$pip" install -q ${reqs[@]+"${reqs[@]}"} ${extra[@]+"${extra[@]}"}
  ok "Python tools ready in $VENV/bin"
}

install_ansible_collections() {
  ((NEED_ANSIBLE)) || return 0
  step "Ansible collections"
  local galaxy="$VENV/bin/ansible-galaxy"
  ((DRY)) || [[ -x "$galaxy" ]] || galaxy=ansible-galaxy
  has 03 && run "$galaxy" collection install -r 03-ansible-infra-provisioning/requirements.yml
  has 05 && run "$galaxy" collection install -r 05-payflow-devops-pipeline/ansible/requirements.yml
  return 0
}

# ----------------------------------------------------------------- Docker daemon
start_docker() {
  ((NEED_DOCKER)) || return 0
  step "Docker daemon"
  if ((DRY)); then info "would start Docker if it is not running"; return; fi
  if docker info >/dev/null 2>&1; then ok "Docker is running"; return; fi
  if [[ "$OS" == Darwin ]]; then
    info "starting Docker Desktop (first start can take a minute)"
    open -a Docker 2>/dev/null || { warn "could not open Docker.app - start Docker Desktop manually"; return; }
  elif cmd_ok systemctl && [[ -d /run/systemd/system ]]; then
    $SUDO systemctl start docker || true
  fi
  local i; for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done
  if docker info >/dev/null 2>&1; then ok "Docker is running"
  elif $SUDO docker info >/dev/null 2>&1; then warn "Docker runs, but only with sudo: log out/in so the docker group applies"
  else warn "Docker is not running yet - start Docker Desktop / dockerd, then re-run ./run.sh doctor"; fi
}

# ----------------------------------------------------------------- main
if [[ "$OS" == Darwin ]]; then
  install_macos
else
  install_linux_packages
  install_linux_docker
  install_linux_binaries
fi
install_python
install_ansible_collections
start_docker
run chmod +x run.sh 0*/run.sh 0*/scripts/*.sh 2>/dev/null || true

step "Done"
if [[ "$OS" == Linux ]] && [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
  warn "$LOCAL_BIN is not on your PATH (run.sh adds it automatically). For your shell: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
fi
if ((${#WARNINGS[@]})); then
  printf '\n%sNotes:%s\n' "$Y" "$N"; for w in "${WARNINGS[@]}"; do printf '  - %s\n' "$w"; done
fi
cat <<EOF

Next steps:
  ./run.sh doctor            check every project
  ./run.sh 02 start          e.g. start the TaskBoard app
EOF
