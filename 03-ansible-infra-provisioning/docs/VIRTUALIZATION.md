# Virtualization Concepts

## Virtual machines vs containers

| | Virtual machine | Container |
|---|---|---|
| Isolation | Full guest OS with its own kernel | Shares the host kernel (namespaces + cgroups) |
| Boot time | tens of seconds | milliseconds to seconds |
| Size | GBs | MBs |
| Use when | Different OS/kernel needed, strong isolation, legacy apps | Packaging and shipping applications |
| In this portfolio | Projects 3 (Vagrant VMs) | Projects 2, 4, 5 (Docker) |

In data centers they are combined: containers run **inside** VMs.

## Hypervisors

* **Type 1 (bare metal):** runs directly on hardware. Examples: VMware ESXi, Microsoft Hyper-V, KVM, Xen. Used in data centers.
* **Type 2 (hosted):** runs as an application on a desktop OS. Examples: VirtualBox, VMware Workstation. Used in this lab.

## VMware vSphere concepts mapped to this lab

| vSphere | Meaning | Lab equivalent |
|---|---|---|
| ESXi host | Physical server running the type-1 hypervisor | Your laptop running VirtualBox |
| vCenter Server | Central management of many ESXi hosts | `vagrant` CLI |
| Cluster | Group of ESXi hosts sharing resources; enables HA/DRS | – |
| Datastore | Storage for VM disks (VMFS, NFS, vSAN) | VirtualBox VM folder |
| Template | Golden VM image used to clone new VMs | Vagrant box `ubuntu/jammy64` |
| Linked clone | Clone sharing the parent's base disk | `vb.linked_clone = true` |
| Snapshot | Point-in-time state of a VM, for rollback | `vagrant snapshot save` |
| vMotion | Live-migrate a running VM between hosts | – |
| HA | Restart VMs on another host if one fails | – |
| DRS | Automatic load balancing of VMs across hosts | – |
| Port group / vSwitch | Virtual network segment | Host-only network 192.168.56.0/24 |
| Resource pool | CPU/RAM limits for a group of VMs | `vb.memory`, `vb.cpus` |

## Snapshots before risky changes

```bash
vagrant snapshot save web01 before-patch
make patch
vagrant snapshot restore web01 before-patch     # if something broke
```

Snapshots are **not backups**. They live on the same storage and slow the
VM down as they grow. Delete them after the change is verified.

## Provisioning flow in a real data center

```
VM template (vCenter) → clone VM (Terraform / vSphere API / manual) → IP in inventory → Ansible site.yml
```

This repo covers the last step. Swapping Vagrant for Terraform's
`vsphere` provider would cover the first two.
