---
date: 2025-07-10
categories:
  - HomeLab
tags: 
    - Blog
    - Proxmox
    - VM Management
---

# Handling VM disk space shortage

## Why Do We Need to Expand VM Disks?

As operations grow, VMs may exhaust their available storage due to logs, growing databases, or installing new services. While it is often preferable to store data on network or dedicated storage volumes and keep only important configuration data on the VM’s main disk, sometimes it is necessary to expand the VM’s disk to accommodate additional data.

Without sufficient space, you may face update failures, data loss, or critical application downtime.

<!-- more -->

## Step 1: Resize Disk Size

Proxmox supports two main methods for increasing the VM disk size:

1. **Using the Proxmox Web UI**  
        Go to “VM → Hardware → \[the disk you want to resize\] → Disk Action → Resize.” Then enter how much to expand.
2. **Using the qm Command**  
        Run the following in the Proxmox server terminal (outside the VM):

```bash
qm resize <VMID> <DISK> +<SIZE>
```

- `<VMID>`: The numeric ID of the VM as shown in Proxmox.
- `<DISK>`: The disk identifier (e.g., scsi0, virtio0).
- `<SIZE>`: The amount of space to add (e.g., `10G` for 10 GiB).

If your storage backend and guest OS support it, you can do this while the VM is running. Otherwise, you may need to shut down the VM for the resize to succeed. After resizing, confirm there are no error messages.

## Step 2: Extend Disk in VM

1. **Check the New Disk Size**  
   Log in to the VM (via SSH or console) and run:

```
lsblk
```

This shows all block devices, including the newly increased disk size.

1. **Adjust the Partition in the VM**  
        For traditional (non-LVM) partitions, you may just need to adjust with parted and then resize the filesystem. For LVM-based setups, you will expand the partition, then the physical volume, and finally the logical volume(s).

   Below is a common example for LVM-based Ubuntu/Debian systems on disk `/dev/sda`:

```bash
# View current partition layout
sudo parted /dev/sda print

# Resize partition to use 100% of the newly available disk space
# Replace <partition-number> with the correct partition index
sudo parted /dev/sda resizepart <partition-number> 100%

# Ask the OS to reread the partition table
sudo partprobe /dev/sda
```

1. **Resize the Filesystem and LVM Structures**  
        Depending on the exact VM setup, use the commands that match your layout:

```bash
# If you have a standard EXT-based filesystem on a partition (not LVM):
sudo resize2fs /dev/sdaX
```

- Replace `/dev/sdaX` with the correct partition device (e.g., `/dev/sda3`).

```bash
# For LVM-based setups:
# 1. Resize the LVM physical volume
sudo pvresize /dev/sdaX

# 2. Extend the logical volume to use all free space
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv

# 3. Finally, expand the filesystem (e.g., EXT4)
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```

For XFS filesystems, replace the `resize2fs` step with:

```bash
sudo xfs_growfs /mount/point
```

(e.g., `/mount/point` might be `/` for the root filesystem).

1. **Verify the Expansion**  
        After these steps, verify the new size with `df -h`

---

### Quick Summary

1. **Proxmox Resize**: Use the UI or the `qm resize` command to expand the virtual disk.
2. **Partition Resize**: Inside the VM, use tools like `parted` or `fdisk` to update the partition table to the new size.
3. **Filesystem/LVM Resize**: Apply `resize2fs`, `pvresize`, `lvextend`, or `xfs_growfs` according to your filesystem.