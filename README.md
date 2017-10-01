GPU + OSP   

https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Virtualization_Deployment_and_Administration_Guide/chap-Guest_virtual_machine_device_configuration.html#sect-device-GPU

https://docs.openstack.org/nova/pike/admin/pci-passthrough.html


1. Deploy undercloud and import overcloud servers to ironic
2. Configure server BIOS to support IOMMU and PCI passthrough
3. Update puppet-nova to ocata stable
4. Deploy overcloud with templates that configure: iommu in grub, pci device aliases, pci device whitelist, and PciPassthrough filter enabled in nova.conf
5. Create custom RHEL 7.4 image with kernel headers/devel and gcc
6. Create custom Nova flavor with PCI device alias
7. Configure cloud-init to install cuda at instance boot time
8. Launch instance from flavor + cloud-init + image via Heat
9. Run sample codes


https://review.openstack.org/#/c/494189/
