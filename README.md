# Deploying GPUs in OpenStack Ocata via Tripleo

Instructions for deploying OpenStack via tripleo with Nvidia P100 GPUs exposed via PCI passthrough.

## Basic workflow
1. Deploy undercloud and import overcloud servers to Ironic
2. Configure server BIOS to support IOMMU and PCI passthrough
3. Update puppet-nova to ocata stable
4. Deploy overcloud with templates that configure: iommu in grub, pci device aliases, pci device whitelist, and PciPassthrough filter enabled in nova.conf
5. Create custom RHEL 7.4 image with kernel headers/devel and gcc
6. Create custom Nova flavor with PCI device alias
7. Configure cloud-init to install cuda at instance boot time
8. Launch instance from flavor + cloud-init + image via Heat
9. Run sample codes


## Resources
- [https://access.redhat.com/solutions/3080471] GPU support in Red Hat OpenStack Platform
- [https://bugzilla.redhat.com/show_bug.cgi?id=1430337](Bugzilla RFE for documentation on confiuring GPUs via PCI passthrough in OpenStack Platform)
- [https://docs.openstack.org/nova/pike/admin/pci-passthrough.html](OpenStack Nova Configure PCI Passthrough)
- [https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Virtualization_Deployment_and_Administration_Guide/chap-Guest_virtual_machine_device_configuration.html#sect-device-GPU](KVM virtual machine GPU configuration)
- [http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#runfile-installation](Nvidia Cuda Linux installation guide)
- [https://access.redhat.com/solutions/1132653](DKMS support in Red Hat Enterprise Linux)
- [http://hardysteven.blogspot.com/2016/08/tripleo-deploy-artifacts-and-puppet.html](Deploying TripleO artifacts)

## Upstream OpenStack patches
- [https://review.openstack.org/476327](https://review.openstack.org/476327): Set pci aliases on computes
- [https://review.openstack.org/482033](https://review.openstack.org/482033): Set pci/alias and pci/passthrough_whitelist instead of DEFAULT/pci_alias and DEFAULT/pci_passthrough_whitelist
- [https://review.openstack.org/494189](https://review.openstack.org/494189): Handle multiple pci aliases/whitelist options
