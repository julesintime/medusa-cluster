# External Storage Integration Guide

Proxmox → VM → Longhorn external drive attachment for backup storage expansion.

## Option 1: Physical Drive Passthrough (Recommended)

### Step 1: Identify Drive on Proxmox Host
```bash
# On Proxmox host (pve200/pve700)
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,MODEL
fdisk -l

# Example output:
# /dev/sdb    2T   ext4              WD_Black_2TB_SN850X
```

### Step 2: Attach Drive to VM
```bash
# On Proxmox host
qm set <VM_ID> -scsi2 /dev/disk/by-id/ata-WD_Black_2TB_SN850X

# Alternative: Hot-plug via Proxmox UI
# VM → Hardware → Add → Hard Disk → Use existing disk
```

### Step 3: Configure Drive in VM  
```bash
# On K3s worker node
lsblk  # Should show new drive as /dev/sdb

# Format drive with ext4
sudo mkfs.ext4 /dev/sdb1

# Create mount point
sudo mkdir -p /mnt/backup-storage

# Mount drive
sudo mount /dev/sdb1 /mnt/backup-storage

# Add to fstab for persistence
echo "/dev/sdb1 /mnt/backup-storage ext4 defaults 0 2" | sudo tee -a /etc/fstab

# Set permissions for Longhorn
sudo chown -R 1001:1001 /mnt/backup-storage
sudo chmod 755 /mnt/backup-storage
```

### Step 4: Configure Longhorn Storage Pool
```yaml
# Create additional Longhorn node disk
apiVersion: longhorn.io/v1beta2
kind: Node
metadata:
  name: k3s-worker-1  # Target node with external drive
spec:
  disks:
    backup-disk:
      path: /mnt/backup-storage
      allowScheduling: true
      storageReserved: 10737418240  # 10GB reserved
      diskType: filesystem
```

## Option 2: Network Storage (NFS/iSCSI)

### NFS Export from Proxmox
```bash
# On Proxmox host
apt install nfs-kernel-server

# Create export directory  
mkdir -p /backup-storage
chown nobody:nogroup /backup-storage

# Configure NFS export
echo "/backup-storage *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
exportfs -ra
systemctl restart nfs-kernel-server
```

### Mount NFS in K3s Nodes
```bash
# On all K3s nodes
apt install nfs-common

# Mount NFS share
mkdir -p /mnt/nfs-backup
mount -t nfs 192.168.8.26:/backup-storage /mnt/nfs-backup

# Add to fstab
echo "192.168.8.26:/backup-storage /mnt/nfs-backup nfs defaults 0 0" >> /etc/fstab
```

### Configure Longhorn with NFS
```yaml
apiVersion: longhorn.io/v1beta2  
kind: Node
metadata:
  name: k3s-worker-1
spec:
  disks:
    nfs-backup:
      path: /mnt/nfs-backup
      allowScheduling: true
      storageReserved: 10737418240
      diskType: filesystem
```

## Option 3: Proxmox LVM-Thin Integration

### Create LVM-Thin Pool on External Drive
```bash
# On Proxmox host with external drive /dev/sdb
pvcreate /dev/sdb
vgcreate backup-vg /dev/sdb
lvcreate -L 1.8T -T backup-vg/backup-pool

# Create Proxmox storage
pvesm add lvmthin backup-storage --vgname backup-vg --thinpool backup-pool
```

### Attach LVM Volume to VM
```bash
# Create volume for VM
pvesm alloc backup-storage <VM_ID> vm-<VM_ID>-backup 100G

# Attach to VM
qm set <VM_ID> -scsi3 backup-storage:vm-<VM_ID>-backup
```

## Security Considerations

### Drive Encryption (Optional)
```bash  
# LUKS encryption before mounting
cryptsetup luksFormat /dev/sdb1
cryptsetup luksOpen /dev/sdb1 backup-encrypted

# Mount encrypted volume
mkfs.ext4 /dev/mapper/backup-encrypted
mount /dev/mapper/backup-encrypted /mnt/backup-storage
```

### Access Control
```bash
# Set proper ownership and permissions
chown root:longhorn /mnt/backup-storage
chmod 750 /mnt/backup-storage

# SELinux context (if enabled)
setsebool -P virt_use_nfs 1
```

## Monitoring Integration

### Disk Health Monitoring
```bash
# Install smartmontools
apt install smartmontools

# Check drive health
smartctl -a /dev/sdb

# Add to Prometheus monitoring
# node_exporter automatically exports SMART data
```

### Storage Metrics
```yaml
# Add storage monitoring to Longhorn
apiVersion: v1
kind: ConfigMap  
metadata:
  name: longhorn-storageclass-monitoring
data:
  monitoring.yaml: |
    disk_usage_alert: 80%
    backup_completion_check: true
```

## Network Configuration

### Bandwidth Optimization
```bash
# For NFS performance tuning
echo "net.core.rmem_default = 262144" >> /etc/sysctl.conf
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf 
echo "net.core.wmem_default = 262144" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
sysctl -p
```

### Firewall Rules
```bash
# Allow NFS traffic
ufw allow from 192.168.8.0/24 to any port 2049
ufw allow from 192.168.8.0/24 to any port 111
```

## Backup Strategy Integration  

### MinIO External Storage
```yaml
# Configure MinIO to use external storage
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: minio
spec:
  values:
    persistence:
      enabled: true
      storageClass: "longhorn"
      size: 500Gi
      # This will use the external drive through Longhorn
```

### Longhorn Backup Target
```bash
# Configure backup to external storage
kubectl create secret generic longhorn-backup-nfs \
  --from-literal=NFS_SERVER=192.168.8.26 \
  --from-literal=NFS_PATH=/backup-storage \
  -n longhorn-system
```

## Troubleshooting

### Common Issues
- **Mount failures**: Check permissions and filesystem type
- **Performance issues**: Use appropriate mount options (noatime, etc.)
- **Network storage timeouts**: Increase NFS timeout values  
- **Longhorn scheduling**: Ensure disk is marked as schedulable

### Validation Commands
```bash
# Check mount status
mount | grep backup
df -h /mnt/backup-storage

# Test Longhorn disk recognition
kubectl get nodes.longhorn.io -o wide

# Verify storage pool
kubectl describe nodes.longhorn.io k3s-worker-1
```

This guide provides multiple approaches for integrating external storage from Proxmox hosts into the Longhorn storage system, enabling expanded backup capacity and improved data resilience.