.PHONY: cleanup-cloudimg
cleanup-cloudimg:
ifndef PROXMOX_NODE
	$(error PROXMOX_NODE is not set)
endif
	ssh $(PROXMOX_NODE) rm -f jammy-server-cloudimg-amd64.img

.PHONY: download-cloudimg
download-cloudimg:
ifndef PROXMOX_NODE
	$(error PROXMOX_NODE is not set)
endif
	ssh $(PROXMOX_NODE) wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O jammy-server-cloudimg-amd64.img

.PHONY: destroy-template
destroy-template:
ifndef PROXMOX_NODE
	$(error PROXMOX_NODE is not set)
endif
ifndef TEMPLATE_VMID
	$(error TEMPLATE_VMID is not set)
endif
	ssh $(PROXMOX_NODE) qm destroy $(TEMPLATE_VMID) --destroy-unreferenced-disks=1 --purge=1 || true

.PHONY: create-template
create-template:
ifndef PROXMOX_NODE
	$(error PROXMOX_NODE is not set)
endif
ifndef TEMPLATE_VMID
	$(error TEMPLATE_VMID is not set)
endif
	ssh $(PROXMOX_NODE) qm create $(TEMPLATE_VMID) --name ubuntu2204-server-template \
			--agent 1 --ostype l26 --memory 2048 --cpu host --cores 4 --net0 virtio,bridge=vmbr0 && \
	ssh $(PROXMOX_NODE) qm importdisk $(TEMPLATE_VMID) jammy-server-cloudimg-amd64.img local-zfs && \
	ssh $(PROXMOX_NODE) qm set $(TEMPLATE_VMID) --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-$(TEMPLATE_VMID)-disk-0,ssd=1 && \
	ssh $(PROXMOX_NODE) qm set $(TEMPLATE_VMID) --ide2 local-zfs:cloudinit && \
	ssh $(PROXMOX_NODE) qm set $(TEMPLATE_VMID) --boot c --bootdisk scsi0 && \
	ssh $(PROXMOX_NODE) qm template $(TEMPLATE_VMID)

.PHONY: template
template:
# pve
	$(MAKE) download-cloudimg PROXMOX_NODE=pve
	$(MAKE) create-template PROXMOX_NODE=pve TEMPLATE_VMID=9000
# pve01
	$(MAKE) download-cloudimg PROXMOX_NODE=pve01
	$(MAKE) create-template PROXMOX_NODE=pve01 TEMPLATE_VMID=9001
# pve02
	$(MAKE) download-cloudimg PROXMOX_NODE=pve02
	$(MAKE) create-template PROXMOX_NODE=pve02 TEMPLATE_VMID=9002

.PHONY: update-template
update-template:
# pve
	$(MAKE) cleanup-cloudimg PROXMOX_NODE=pve
	$(MAKE) download-cloudimg PROXMOX_NODE=pve
	$(MAKE) destroy-template PROXMOX_NODE=pve TEMPLATE_VMID=9000
	$(MAKE) create-template PROXMOX_NODE=pve TEMPLATE_VMID=9000

# pve01
	$(MAKE) cleanup-cloudimg PROXMOX_NODE=pve01
	$(MAKE) download-cloudimg PROXMOX_NODE=pve01
	$(MAKE) destroy-template PROXMOX_NODE=pve01 TEMPLATE_VMID=9001
	$(MAKE) create-template PROXMOX_NODE=pve01 TEMPLATE_VMID=9001

# pve02
	$(MAKE) cleanup-cloudimg PROXMOX_NODE=pve02
	$(MAKE) download-cloudimg PROXMOX_NODE=pve02
	$(MAKE) destroy-template PROXMOX_NODE=pve02 TEMPLATE_VMID=9002
	$(MAKE) create-template PROXMOX_NODE=pve02 TEMPLATE_VMID=9002
