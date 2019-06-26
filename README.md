HPC tests used in HPC-CI with terraform libvirt provider as the
test environment.

You can also find some simplistic shell tests which can be executed
on the HPC cluster provisioned in a diffrent way, for instance by openQA.

The test repository is providing HPC tests which are meant to
run in combination with terraform tool. For details see:
https://www.terraform.io/

The terraform provider being used is: libvirt Please see:
https://github.com/dmacvicar/terraform-provider-libvirt

Both, the terraform tool, as well as terraform-provider-libvirt must be installed on the system to run the tests.

The project provides .tf files.

# Table of Contents
1. [Terraform Installation](#terraform-installation)
2. [VM images](#vm-images)
3. [Terraform usage](#terraform-usage)
4. [Common errors](#common-errors)

## Terraform Installation

The following section provides a set of instructions to install Terraform together with the libvirt provider along with the virtualization packages.

### Leap 15.0
```sh
zypper ar -G https://download.opensuse.org/repositories/systemsmanagement:/terraform/openSUSE_Leap_15.0/systemsmanagement:terraform.repo
zypper in -y libvirt terraform terraform-provider-libvirt
systemctl enable libvirtd
systemctl status libvirtd
```
### Other OpenSuse versions

For Tumbleweed, the following repository must be used:

    https://download.opensuse.org/repositories/systemsmanagement:/terraform/openSUSE_Tumbleweed/systemsmanagement:terraform.repo

For 42.3, the following repository shall be used:
```sh
https://download.opensuse.org/repositories/systemsmanagement:/terraform/openSUSE_Leap_42.3/systemsmanagement:terraform.repo
```

### Manual Installation
Terraform also comes as downloadable binary for Linux, you can find all the builds (even beta versions of releases in development) [here](https://releases.hashicorp.com/terraform/).

Just extract the .zip and place the binary in ```/usr/bin/terraform```.

**NOTE**: It is recommended to use the official repositories to avoid compatibility issues.

## VM images

Terraform takes an image (e.g. qcow2) and boots it without user interaction. If you want to use features like assigning an IP automatically (DHCP), you will need to prepare an image to boot automatically a pre-installed OS with proper ifcfg files according to your needs.

### Example
Prepare image with only 1 NIC with DHCP IP assignment:

1) Make sure the image contains a pre-installed OS.
2) GRUB_TIMEOUT parameter should be set to 0 or any other value different than -1 in /etc/default/grub
3) Remove /etc/udev/rules.d/70-persistent-net.rules to force usage of eth0
4) Make sure /etc/sysconfig/network/ifcfg-eth0 contains BOOTPROTO='dhcp'



## Terraform usage

Terraform works on directory as environment. Normally, for each configuration, a directory shall be created.

Create a directory ```example``` and place the corresponding .tf file in it.
```sh
terraform init
terraform apply -auto-approve
```

To clean the environment (VM, disk, network, ...) run the command:
```sh
terraform destroy -auto-approve
```

## Common errors

* **libvirt_volume.myvdisk: can't find storage pool 'default'**
    Create the default storage pool by doing:
    ```sh
    virsh pool-create-as --name default --type dir --target /var/lib/libvirt/images
    ```

* **libvirt_domain.domain-sle: Error defining libvirt domain: virError(Code=8, Domain=44, Message='invalid argument: could not find capabilities for domaintype=kvm ')**
    This is a common problem when using nested virtualization. If you are running Terraform inside a VM, make sure Nested Virtualization is enabled on the host and on the VM you can find the Virtual-Machine eXtensions (VMX) CPU flag ```lscpu|grep vmx```.
    A quick way to check that feature in your VM is by issuing the command ```virt-host-validate```.
    If you get the following output, you probably don't have Nested Virtualization enabled as the result shall be "PASS".

    > QEMU: Checking for hardware virtualization : FAIL (Only emulated CPUs are available, performance will be significantly limited)

    [This guide](https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/) provides comprehensive information with all the steps to enable Nested Virtualization.
