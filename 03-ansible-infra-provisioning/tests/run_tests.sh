#!/usr/bin/env bash
# Offline test suite: no VMs needed.
#   ./tests/run_tests.sh
set -Eeuo pipefail
cd "$(dirname "$0")/.."
OUT=tests/.rendered
pass() { echo "PASS  $*"; }
# check "description" command... : fail loudly (set -e does not trigger inside && chains)
check() { local d="$1"; shift; if "$@"; then pass "$d"; else echo "FAIL  $d" >&2; exit 1; fi; }

ansible-lint -q && pass "ansible-lint (production profile)"
yamllint -c .yamllint.yml . && pass "yamllint"
for p in playbooks/*.yml; do ansible-playbook --syntax-check "$p" >/dev/null; done && pass "syntax-check all playbooks"

# --- templates render from the real inventory ---
ansible-playbook -i inventories/vagrant/hosts.ini tests/render_templates.yml >/dev/null
check "LB upstream generated from inventory (web01, web02)" \
  bash -c "grep -q 'server 192.168.56.11:8000' $OUT/lb.conf && grep -q 'server 192.168.56.12:8000' $OUT/lb.conf"
check "LB algorithm applied" grep -q "least_conn;" $OUT/lb.conf

ansible-playbook -i inventories/vagrant/hosts.ini tests/render_templates.yml -e '{"lb_drained_hosts": ["web01"]}' >/dev/null
check "draining web01 marks only web01 down" \
  bash -c "grep -q '192.168.56.11:8000 .* down;' $OUT/lb.conf && ! grep -q '192.168.56.12:8000 .* down;' $OUT/lb.conf"

if command -v nginx >/dev/null; then
  printf 'events {}\nhttp { include %s/lb.conf; }\n' "$PWD/$OUT" > $OUT/nginx.conf
  # test copy: writable log path and an unprivileged port, so nginx -t runs without root
  sed -i -e 's#/var/log/nginx/lb_access.log#/tmp/lb_access.log#' -e 's/listen [0-9]\+ default_server/listen 18080 default_server/' $OUT/lb.conf
  check "rendered LB config passes nginx -t" nginx -t -q -c "$PWD/$OUT/nginx.conf" -g "pid /tmp/nginx-test.pid; error_log /tmp/nginx-test.err;"
fi
check "sshd hardening rendered" bash -c "grep -q 'PermitRootLogin no' $OUT/sshd.conf && grep -q 'PasswordAuthentication no' $OUT/sshd.conf"
command -v systemd-analyze >/dev/null && systemd-analyze verify $OUT/hello-dc.service 2>/dev/null && pass "systemd unit verifies" || true

# --- app behaviour: health, version, drain ---
PORT=18765; DRAIN=$(mktemp -u)
APP_PORT=$PORT APP_VERSION=9.9.9 DRAIN_FILE=$DRAIN python3 roles/webapp/files/app.py >/dev/null 2>&1 &
pid=$!; trap 'kill $pid 2>/dev/null || true; rm -rf $OUT' EXIT   # || true: the app is already stopped by the SIGTERM test
sleep 1
code() { curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT$1"; }
check "app /health returns 200" test "$(code /health)" = "200"
check "app reports configured version" bash -c "curl -s localhost:$PORT/ | grep -q '\"version\": \"9.9.9\"'"
touch "$DRAIN"
check "app returns 503 while draining" test "$(code /health)" = "503"
rm -f "$DRAIN"
check "app healthy again after drain removed" test "$(code /health)" = "200"
check "app returns 404 for unknown paths" test "$(code /nope)" = "404"
kill -TERM $pid
check "app exits cleanly on SIGTERM (systemctl stop)" timeout 5 tail --pid=$pid -f /dev/null
echo "all tests passed"
