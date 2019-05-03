#!/bin/bash
#
# This is a POC for HPC slurm terraform ltp test controller
#
 
TST_TESTFUNC=test
TST_SETUP=setup
TST_CLEANUP=cleanup
TST_NEEDS_TMPDIR=1
TF_ORIGIN=/root/terraform/sle12sp3-slurm/
 
PATH=/opt/ltp/testcases/bin:/usr/bin:$PATH
LTPROOT=/opt/ltp

. ${LTPROOT}/testcases/bin/tst_test.sh
 
 
rcmd (){
    EXPECT_PASS sshpass -plinux ssh -o StrictHostKeyChecking=no root@$1 "$2"
}

usercmd() {
    EXPECT_PASS sshpass -plinux ssh -o StrictHostKeyChecking=no auser@$1 "$2"
}
 
rcmd_brk (){
        ROD sshpass -plinux ssh -o StrictHostKeyChecking=no root@$1 "$2"
}
 
set_hostname()
{
        tst_res TINFO "Setting hostname $2 on ${nodes[$1]}"
        rcmd_brk ${nodes[$1]} "hostnamectl set-hostname $2"
        rcmd_brk ${nodes[$1]} "systemctl restart network"
        rcmd_brk ${nodes[$1]} hostname
}

set_hosts_file()
{
	tst_res TINFO "Creating hosts file ${nodes[$1]}"
	rcmd_brk ${nodes[$1]} "echo -e '${nodes[0]} controller\n${nodes[1]} compute\n' >> /etc/hosts"
}
 
 
zypper_in()
{
    tst_res TINFO "Installing $2 on ${nodes[$1]}"
        rcmd_brk ${nodes[$1]} "zypper in -y  $2"
}
 
systemctl()
{
        rcmd_brk ${nodes[$1]} "systemctl $2"
}
 
setup()
{
    tst_res TINFO "Creating virtual machines at $(pwd)"
    ROD cp $TF_ORIGIN/hpc_slurm.tf .
    ROD terraform init
    ROD terraform apply -auto-approve
    sleep 30
 
    nodes=($(terraform output | grep 10 | awk {'print $1'}))
 
    for node in "${nodes[@]}"; do
        tst_res TINFO "Checking connection to node $node"
        rcmd_brk $node "ip a"
        rcmd_brk $node "zypper in -y sshpass mpitests-openmpi"
    done
 
    set_hostname 0 "controller"
    set_hostname 1 "compute"

    set_hosts_file 0
    set_hosts_file 1
 
    zypper_in 0 "slurm slurm-munge nfs-kernel-server"
    zypper_in 1 "slurm-munge slurm nfs-client"
 
        rcmd_brk ${nodes[0]} "sed -i \"/^ControlMachine.*/c\\ControlMachine=controller\" /etc/slurm/slurm.conf"
        rcmd_brk ${nodes[0]} "sed -i \"/^NodeName.*/c\\NodeName=controller,compute Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown\" /etc/slurm/slurm.conf"
        rcmd_brk ${nodes[0]} "sed -i \"/^PartitionName.*/c\\PartitionName=normal Nodes=controller,compute Default=YES MaxTime=24:00:00 State=UP\" /etc/slurm/slurm.conf"
        rcmd_brk ${nodes[0]} "sed -i \"/^Epilog=/d\" /etc/slurm/slurm.conf"
 
    tst_res TINFO "Copying config to compute node"
    rcmd_brk ${nodes[0]} "sshpass -plinux scp -o StrictHostKeyChecking=no /etc/munge/munge.key root@compute:/etc/munge/munge.key"
        rcmd_brk ${nodes[0]} "sshpass -plinux scp -o StrictHostKeyChecking=no /etc/slurm/slurm.conf root@compute:/etc/slurm/slurm.conf"
 
    tst_res TINFO "Starting controller node"
    systemctl 0 "start munge"
    systemctl 0 "start slurmctld"
    systemctl 0 "start slurmd"
 
    tst_res TINFO "Starting compute node"
    systemctl 1 "start munge"
    systemctl 1 "start slurmd"
 
        tst_res TINFO "Checking controller node"
        systemctl 0 "status munge"
        systemctl 0 "status slurmctld"
        systemctl 0 "status slurmd"
 
        tst_res TINFO "Checking compute node"
        systemctl 1 "status munge"
        systemctl 1 "status slurmd"

	tst_res TINFO "Starting nfs-server"
	rcmd_brk ${nodes[0]} "echo '/home *(rw,sync,no_root_squash,no_subtree_check)' >> /etc/exports"
	systemctl 0 "start nfs-server"

	tst_res TINFO "Checking nfs server"
	systemctl 0 "status nfs-server"

	tst_res TINFO "Starting nfs client"
	rcmd_brk ${nodes[1]} "mount controller://home /home"

	tst_res TINFO "Adding user auser"
	# beware of the hashed password it contains magic characters
	rcmd_brk ${nodes[0]} "useradd -m -u 1000 -p '\$1\$wYJUgpM5\$RXMMeASDc035eX.NbYWFl0' auser"
	rcmd_brk ${nodes[1]} "useradd -u 1000 -p '\$1\$wYJUgpM5\$RXMMeASDc035eX.NbYWFl0' auser"

	usercmd ${nodes[0]} "ssh-keygen -P '' -f /home/auser/.ssh/id_rsa"
	usercmd ${nodes[0]} "cat .ssh/id_rsa.pub >> .ssh/authorized_keys"
	usercmd ${nodes[0]} "echo StrictHostKeyChecking=no >> .ssh/config"
	usercmd ${nodes[0]} "mpi-selector --set openmpi"

}
 
test()
{
    usercmd ${nodes[0]} "mpirun -H controller,compute -n 2 /usr/lib64/mpi/gcc/openmpi/tests/IMB/IMB-EXT"
    usercmd ${nodes[0]} "sinfo"
    usercmd ${nodes[0]} "srun -N 2 hostname"
    usercmd ${nodes[0]} "srun -w compute hostname | grep compute"
    usercmd ${nodes[0]} "srun -N 2 date"
    usercmd ${nodes[0]} "echo -e \"#!/bin/bash\nmpirun usr/lib64/mpi/gcc/openmpi/tests/IMB/IMB-EXT\n\" > mpitest.sh"
    usercmd ${nodes[0]} "sbatch -N 2 mpitest.sh"

}  
 
cleanup()
{
        tst_res TINFO "Destroying virtual machines"
        #terraform destroy -auto-approve
}
 
tst_run
