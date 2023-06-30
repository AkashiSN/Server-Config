# infra

## Create template vm

```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

vmid=9000

qm create $vmid --name ubuntu2204-server-template --agent 1 --ostype l26 --memory 2048 --cpu host --cores 4 --net0 virtio,bridge=vmbr0

qm importdisk $vmid jammy-server-cloudimg-amd64.img local-zfs

qm set $vmid --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-$vmid-disk-0,ssd=1

qm set $vmid --ide2 local-zfs:cloudinit

qm set $vmid --boot c --bootdisk scsi0

qm template $vmid
```

## Create proxmox user for terraform

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"

pveum user add terraform-prov@pve --password <password>

pveum aclmod / -user terraform-prov@pve -role TerraformProv

pvesh create /access/users/terraform-prov@pve/token/terraform --privsep 0
```

## Plan and Apply

```bash
terraform plan
terraform apply
```
