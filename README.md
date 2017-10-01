# Deploying GPUs in OpenStack Ocata via Tripleo

Instructions for deploying OpenStack via tripleo with Nvidia P100 GPUs exposed via PCI passthrough.

## Basic workflow
1. Deploy undercloud and import overcloud servers to Ironic
2. Enable IOMMU in server BIOS to support PCI passthrough
3. Update puppet-nova to stable Ocata
4. Deploy overcloud with templates that configure: iommu in grub, pci device aliases, pci device whitelist, and PciPassthrough filter enabled in nova.conf
5. Customize RHEL 7.4 image with kernel headers/devel and gcc
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


## Update puppet-nova to stable Ocata

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


## Create TripleO environment files

Create TripleO environment files to configure nova.conf on the overcloud nodes running nova-compute and nova-scheduler.

```
cat templates/environments/20-compute-params.yaml 
parameter_defaults:

  NovaPCIPassthrough:
        - vendor_id: "10de"
          product_id: "15f8"

cat templates/environments/20-controller-params.yaml 
parameter_defaults:

  NovaSchedulerDefaultFilters: ['AvailabilityZoneFilter','RamFilter','ComputeFilter','ComputeCapabilitiesFilter','ImagePropertiesFilter','ServerGroupAntiAffinityFilter','ServerGroupAffinityFilter', 'PciPassthroughFilter', 'NUMATopologyFilter', 'AggregateInstanceExtraSpecsFilter']

  ControllerExtraConfig:
    nova::api::pci_alias:
      -  name: a1
         product_id: '15f8'
         vendor_id: '10de'
      -  name: a2
         product_id: '15f8'
         vendor_id: '10de'

```

In the above example, the controller node aliases two P100 cards with the names *a1* and *a2*. Depending on the flavor, either or both cards can be assigned to an instance.

iommu must be enabled at boot time on the compute nodes as well. This is accomplished through a the firstboot extraconfig hook.

```
cat templates/environments/10-firstboot-environment.yaml 
resource_registry:
  OS::TripleO::NodeUserData: /home/stack/templates/firstboot/first-boot.yaml

cat templates/firstboot/first-boot.yaml 
heat_template_version: 2014-10-16


resources:
  userdata:
    type: OS::Heat::MultipartMime
    properties:
      parts:
      - config: {get_resource: compute_kernel_args}


  # Verify the logs on /var/log/cloud-init.log on the overcloud node
  compute_kernel_args:
    type: OS::Heat::SoftwareConfig
    properties:
      config: |
        #!/bin/bash
        set -x

        # Set grub parameters
        if hostname | grep compute >/dev/null
        then
                sed -i.orig 's/quiet"$/quiet intel_iommu=on iommu=pt"/' /etc/default/grub
                grub2-mkconfig -o /etc/grub2.cfg
                systemctl stop os-collect-config.service
                /sbin/reboot
        fi

outputs:
  OS::stack_id:
    value: {get_resource: userdata}
```

## Customize the RHEL 7.4 image

Download the [RHEL 7.4 KVM guest image](https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.4/x86_64/product-software) and customize it.


```
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --root-password password:redhat
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager register --username=REDACTED --password=REDACTED'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager attach --pool=8a85f9823e3d5e43013e3dce8ff306fd'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --disable=\*'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-extras-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-rh-common-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-optional-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'yum install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) gcc pciutils wget'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --update
```

Upload the customized image:

```
source ~/overcloudrc
openstack image create --disk-format qcow2 --container-format bare --public --file images/rhel-7.4-gpu.qcow2 rhel7.4-gpu
openstack image list
openstack keypair create stack > stack.pem
chmod 600 stack.pem
```

Create a flavor to use the image and the device alias:

```
openstack flavor create --ram 16384 --disk 40 --vcpus 8 m1.xmedium
```

This repository includes Heat templates [[1]](templates/heat/lab8_admin.yaml)[[2]](templates/heat/lab8_user.yaml) that launch an instance from the image and flavor and that automatically install the Cuda drivers and utilities.

```
source ~/overcloudrc
openstack stack create -t templates/heat/lab8_admin.yaml lab8_admin
sed -e 's/OS_USERNAME=admin/OS_USERNAME=user1/' -e 's/OS_PROJECT_NAME=admin/OS_PROJECT_NAME=tenant1/' -e 's/OS_PASSWORD=.\*/OS_PASSWORD=redhat/' overcloudrc > ~/user1.rc
source ~/user1.rc
openstack stack create -t templates/heat/lab8_user.yaml
openstack stack resource list lab8_user
+---------------------+--------------------------------------+----------------------------+-----------------+----------------------+
| resource_name       | physical_resource_id                 | resource_type              | resource_status | updated_time         |
+---------------------+--------------------------------------+----------------------------+-----------------+----------------------+
| server_init         | 54574cd7-51a5-41a9-9a57-29e7eede06eb | OS::Heat::MultipartMime    | CREATE_COMPLETE | 2017-10-01T06:19:29Z |
| server1_port        | 68360b2e-f892-4240-8f21-92b9eea85cba | OS::Neutron::Port          | CREATE_COMPLETE | 2017-10-01T06:19:29Z |
| cuda_init           | 9d7fe1d1-4b15-4eb8-8a57-b142b3d82258 | OS::Heat::SoftwareConfig   | CREATE_COMPLETE | 2017-10-01T06:19:29Z |
| server1             | 1dc5d97c-3986-43f3-a4e7-6eca419de0af | OS::Nova::Server           | CREATE_COMPLETE | 2017-10-01T06:19:29Z |
| security_group      | dba31123-2d7d-4a34-9f7b-be9c3791d73a | OS::Neutron::SecurityGroup | CREATE_COMPLETE | 2017-10-01T06:19:29Z |
| server1_floating_ip | 423e7657-b12b-4ab0-a96a-0236dd1b3c82 | OS::Neutron::FloatingIP    | CREATE_COMPLETE | 2017-10-01T06:19:29Z |
+---------------------+--------------------------------------+----------------------------+-----------------+----------------------+
```

Verify the drivers are installed correctly:

```
openstack server list 
+--------------------------------------+------+--------+----------------------------------------+-------------+
| ID                                   | Name | Status | Networks                               | Image Name  |
+--------------------------------------+------+--------+----------------------------------------+-------------+
| 1dc5d97c-3986-43f3-a4e7-6eca419de0af | vm1  | ACTIVE | internal_net=192.168.0.7, 172.16.0.212 | rhel7.4-gpu |
+--------------------------------------+------+--------+----------------------------------------+-------------+
ssh -l cloud-user -i stack.pem 172.16.0.212 sudo lspci | grep -i nvidia
00:06.0 3D controller: NVIDIA Corporation GP100GL [Tesla P100 PCIe 16GB] (rev a1)
00:07.0 3D controller: NVIDIA Corporation GP100GL [Tesla P100 PCIe 16GB] (rev a1)
ssh -l cloud-user -i stack.pem 172.16.0.212 sudo lsmod | grep -i nvidia
nvidia_drm             44108  0 
nvidia_modeset        841750  1 nvidia_drm
nvidia              13000758  1 nvidia_modeset
drm_kms_helper        159169  2 cirrus,nvidia_drm
drm                   370825  5 ttm,drm_kms_helper,cirrus,nvidia_drm
i2c_core               40756  4 drm,i2c_piix4,drm_kms_helper,nvidia
```


## Run sample codes

Perform the following steps to verify PCI passthrough and Cuda and properly configured.

```
cat /proc/driver/nvidia/version
NVIDIA_CUDA-9.0_Samples/1_Utilities/deviceQuery/deviceQuery 
NVIDIA_CUDA-9.0_Samples/1_Utilities/p2pBandwidthLatencyTest/p2pBandwidthLatencyTest 
NVIDIA_CUDA-9.0_Samples/1_Utilities/bandwidthTest/bandwidthTest
```
Manual instructions for installing Cuda drivers and utilities are found in the [Nvidia Cuda Linux installation guide](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#runfile-installation).
