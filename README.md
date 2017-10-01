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
- [GPU support in Red Hat OpenStack Platform](https://access.redhat.com/solutions/3080471)
- [Bugzilla RFE for documentation on confiuring GPUs via PCI passthrough in OpenStack Platform](https://bugzilla.redhat.com/show_bug.cgi?id=1430337)
- [OpenStack Nova Configure PCI Passthrough](https://docs.openstack.org/nova/pike/admin/pci-passthrough.html)
- [KVM virtual machine GPU configuration](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Virtualization_Deployment_and_Administration_Guide/chap-Guest_virtual_machine_device_configuration.html#sect-device-GPU)
- [Nvidia Cuda Linux installation guide](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#runfile-installation)
- [DKMS support in Red Hat Enterprise Linux](https://access.redhat.com/solutions/1132653)
- [Deploying TripleO artifacts](http://hardysteven.blogspot.com/2016/08/tripleo-deploy-artifacts-and-puppet.html)


## Update puppet-nova to ocata stable

At the time of writing, we need to update puppet-nova to the latest version on the stable Ocata branch in order to consume the following fixes:

- [https://review.openstack.org/476327](https://review.openstack.org/476327): Set pci aliases on computes
- [https://review.openstack.org/482033](https://review.openstack.org/482033): Set pci/alias and pci/passthrough_whitelist instead of DEFAULT/pci_alias and DEFAULT/pci_passthrough_whitelist
- [https://review.openstack.org/494189](https://review.openstack.org/494189): Handle multiple pci aliases/whitelist options

Use the TripleO artifacts facility to update puppet-nova prior to running overcloud deploy. [TripleO artifacts](http://hardysteven.blogspot.com/2016/08/tripleo-deploy-artifacts-and-puppet.html) are described in this excellent blog post by Heat developer Steve Hardy.

```
source stackrc
mkdir puppet-modules
cd puppet-modules
git clone git://git.openstack.org/openstack/puppet-nova -b stable/ocata nova
ls nova
cd ..
upload-puppet-modules -d puppet-modules
swift list overcloud-artifacts
cat /home/stack/.tripleo/environments/puppet-modules-url.yaml 
diff -y puppet-modules/nova/manifests/api.pp /etc/puppet/modules/nova/manifests/api.pp --suppress-common-lines
```

Once these patches are merged to the Red Hat OpenStack Platform release this step will not be needed.

## Running sample codes

Perform the following steps to verify PCI passthrough and Cuda and properly configured.

```
lspci | grep -i nvidia
lsmod | grep -i nvidia
cat /proc/driver/nvidia/version
NVIDIA_CUDA-9.0_Samples/1_Utilities/deviceQuery/deviceQuery 
NVIDIA_CUDA-9.0_Samples/1_Utilities/p2pBandwidthLatencyTest/p2pBandwidthLatencyTest 
NVIDIA_CUDA-9.0_Samples/1_Utilities/bandwidthTest/bandwidthTest
```
Manual instructions for installing Cuda drivers and utilities are found in the [Nvidia Cuda Linux installation guide](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#runfile-installation).
