# Role Reference

## common

| Variable | Default | Description |
|---|---|---|
| `common_packages` | curl, vim, htop, jq, git, chrony, ufw, unattended-upgrades | Baseline packages |
| `timezone` | `UTC` | System timezone |
| `admin_users` | `[]` | List of `{name, comment, ssh_key, sudo}` |
| `removed_users` | `[]` | Accounts to delete (with home directories) |
| `ssh_allow_password_auth` | `false` | Allow password SSH logins |
| `firewall_allowed_tcp_ports` | `[22]` | Ports open on every host |
| `firewall_extra_tcp_ports` | `[]` | Extra ports set per group |
| `monitoring_allowed_cidr` | `10.0.0.0/8` | Source network allowed to scrape :9100 |
| `sysctl_settings` | see defaults | Kernel parameters written to `/etc/sysctl.d/60-hardening.conf` |

Task files: `main.yml` → `users.yml`, `ssh.yml`, `firewall.yml`.
Handler: `Restart sshd`.

**Safety:** port 22 is always allowed **before** UFW is enabled. The sshd
config and sudoers file are validated (`sshd -t`, `visudo -c`) before
they are written, so a typo cannot lock you out.

## webapp

| Variable | Default | Description |
|---|---|---|
| `webapp_name` | `hello-dc` | systemd unit name |
| `webapp_user` | `webapp` | System user the service runs as |
| `webapp_dir` | `/opt/hello-dc` | Install path |
| `webapp_port` | `8000` | Listen port |
| `webapp_version` | `1.0.0` | Version string reported by the app |
| `webapp_health_retries` | `10` | Health check attempts after deploy |

After deployment, the role flushes handlers so restarts happen immediately,
then **verifies** two things: `/health` returns 200, and `/` reports the
expected `webapp_version`. A deploy that "succeeds" but runs the wrong
version fails the play.

The demo service (`files/app.py`) uses only the Python standard library.
Creating `/run/hello-dc/drain` makes `/health` return 503.

## nginx_lb

| Variable | Default | Description |
|---|---|---|
| `lb_listen_port` | `80` | Frontend port |
| `lb_algorithm` | `least_conn` | `least_conn`, `ip_hash`, or empty for round robin |
| `lb_backend_port` | `8000` | Backend port |
| `lb_backend_group` | `webservers` | Inventory group used to build the upstream |
| `lb_max_fails` / `lb_fail_timeout` | `2` / `10s` | Passive health check |
| `lb_drained_hosts` | `[]` | Hosts rendered as `down` |

`tasks/set_backends.yml` is a reusable entry point used by the rolling
update. It renders the config on every load balancer (delegation),
validates it with `nginx -t`, and reloads only where it changed.

## node_exporter

| Variable | Default |
|---|---|
| `node_exporter_version` | `1.8.2` |
| `node_exporter_arch` | `amd64` |
| `node_exporter_port` | `9100` |

The role checks the installed version first and downloads only when it
differs. That keeps re-runs fast and idempotent.
