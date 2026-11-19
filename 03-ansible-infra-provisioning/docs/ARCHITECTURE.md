# Architecture

## Hosts

| Host | IP (lab) | Group | Services | Open ports |
|---|---|---|---|---|
| lb01 | 192.168.56.10 | loadbalancers | nginx, node_exporter | 22, 80, 9100 (monitoring net only) |
| web01 | 192.168.56.11 | webservers | hello-dc, node_exporter | 22, 8000, 9100 (monitoring net only) |
| web02 | 192.168.56.12 | webservers | hello-dc, node_exporter | 22, 8000, 9100 (monitoring net only) |

Vagrant forwards host port 8080 → lb01:80.

## Request flow

```
client → lb01:80 (nginx, least_conn)
           ├─ web01:8000  hello-dc
           └─ web02:8000  hello-dc
```

* **Passive health checks:** after `max_fails=2` errors within
  `fail_timeout=10s`, nginx stops sending traffic to a backend for 10s.
* **Retry:** `proxy_next_upstream error timeout http_502 http_503` resends
  a failed request to the other server, so a single backend failure is
  invisible to the client.
* The `X-Upstream` response header shows which backend answered.

## Variable hierarchy

```
roles/*/defaults/main.yml          lowest   – safe defaults
inventories/<env>/group_vars/all   ↓        – shared per environment
inventories/<env>/group_vars/<grp> ↓        – per group (webservers, loadbalancers)
-e on the command line             highest  – e.g. webapp_version for a release
```

`lab` and `production` share all roles. They differ only in inventory
files (IPs, admin users, monitoring CIDR, `env_name`).

## Security baseline (every host)

* SSH: key-only, no root login, `MaxAuthTries 3`, only `sudo`/`vagrant` groups may log in.
* UFW: default deny incoming; only required ports; node_exporter restricted by source CIDR.
* Kernel: SYN cookies, ICMP redirect protection, broadcast ping ignore.
* Time: chrony (accurate time matters for logs, TLS and distributed systems).
* Patching: unattended security upgrades daily; `patch.yml` for full upgrades.
* App: runs as a non-login system user under systemd sandboxing.
