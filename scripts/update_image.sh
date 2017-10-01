#!/bin/bash
# This script prepares the image

# download RHEL 7.4 KVM guest image from https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.4/x86_64/product-software 
# as ~/rhel-serevr-7.4-kvm.qcow2
mkdir ~/images
cp rhel-server-7.4-kvm.qcow2 images/rhel-7.4-gpu.qcow2

# customize the image
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --root-password password:redhat
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager register --username=REDACTED --password=REDACTED'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager attach --pool=8a85f9823e3d5e43013e3dce8ff306fd'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --disable=*'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-extras-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-rh-common-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-optional-rpms'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --run-command 'yum install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) gcc pciutils wget'
virt-customize --selinux-relabel -a images/rhel-7.4-gpu.qcow2 --update

# prepare the overcloud
source ~/overcloudrc
openstack image create --disk-format qcow2 --container-format bare --public --file images/rhel-7.4-gpu.qcow2 rhel7.4-gpu
openstack image list
openstack keypair create stack > stack.pem
chmod 600 stack.pem

# deploy the admin stack (creates project, user, networks)
openstack stack create -t templates/heat/lab8_admin.yaml lab8_admin

# deploy the project stack (launches instance, installs cuda via OS::Heat::SoftwareConfig)
sed -e 's/OS_USERNAME=admin/OS_USERNAME=user1/' -e 's/OS_PROJECT_NAME=admin/OS_PROJECT_NAME=tenant1/' -e 's/OS_PASSWORD=.*/OS_PASSWORD=redhat/' overcloudrc > ~/user1.rc
source ~/user1.rc
openstack stack create -t templates/heat/lab8_user.yaml
