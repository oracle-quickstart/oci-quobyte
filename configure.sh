#!/bin/bash
#
# Cluster init configuration script
#
set -x
#
# wait for cloud-init completion on the bastion host
#
execution=1

ssh_options="-i ~/.ssh/cluster.key -o StrictHostKeyChecking=no"
sudo cloud-init status --wait
#
# Install ansible and other required packages
#
##sudo yum makecache
##sudo yum install -y ansible python-netaddr

# OL8.x requirements
#sudo yum install oracle-epel-release-el8.x86_64
#sudo yum makecache --enablerep=ol8_developer_EPEL
#sudo yum install --enablerep=ol8_developer_EPEL -y ansible python3-netaddr


source /etc/os-release

if [ $ID == "ol" ] ; then
  echo $VERSION_ID | grep "^7."
  if [ $? -eq 0 ] ; then
    repo="ol7_developer_EPEL"
  else
    repo="ol8_developer_EPEL"
  fi
elif [ $ID == "centos" ] ; then
  repo="epel"
fi

# to ensure existing enabled repos are available.
if [ $ID == "ol" ] ; then
  sudo osms unregister
fi

# Install ansible and other required packages

if [ $ID == "ol" ] || [ $ID == "centos" ] ; then
  echo $VERSION_ID | grep "^7."
  if [ $? -eq 0 ] ; then
    packages="ansible python-netaddr"
  else
    packages="ansible python3-netaddr"
  fi
  
  sudo yum makecache --enablerepo=$repo
  sudo yum install --enablerepo=$repo -y $packages

elif [ $ID == "debian" ] || [ $ID == "ubuntu" ] ; then
  if [ $ID == "debian" ] && [ $VERSION_ID == "9" ] ; then
    echo deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main | sudo tee -a /etc/apt/sources.list
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
  fi
  sudo apt-get update
  sudo apt -y install ansible python-netaddr

fi

ansible-galaxy collection install ansible.netcommon > /dev/null
ansible-galaxy collection install community.general > /dev/null
ansible-galaxy collection install ansible.posix > /dev/null

threads=$(nproc)
forks=$(($threads * 8))

sudo sed -i "s/^#forks.*/forks = ${forks}/" /etc/ansible/ansible.cfg
sudo sed -i "s/^#fact_caching=.*/fact_caching=jsonfile/" /etc/ansible/ansible.cfg
sudo sed -i "s/^#fact_caching_connection.*/fact_caching_connection=\/tmp\/ansible/" /etc/ansible/ansible.cfg
sudo sed -i "s/^#bin_ansible_callbacks.*/bin_ansible_callbacks=True/" /etc/ansible/ansible.cfg
sudo sed -i "s/^#stdout_callback.*/stdout_callback=yaml/" /etc/ansible/ansible.cfg
sudo sed -i "s/^#retries.*/retries=5/" /etc/ansible/ansible.cfg
sudo sed -i "s/^#connect_timeout.*/connect_timeout=300/" /etc/ansible/ansible.cfg
sudo sed -i "s/^#command_timeout.*/command_timeout=120/" /etc/ansible/ansible.cfg





#
# A little waiter function to make sure all the nodes are up before we start configure 
#

echo "Waiting for SSH to come up" 

for host in $(cat /tmp/hosts) ; do
  r=0 
  echo "validating connection to: ${host}"
  while ! ssh ${ssh_options} opc@${host} uptime ; do

	if [[ $r -eq 10 ]] ; then 
		  execution=0
		  continue
	fi 
        
	echo "Still waiting for ${host}"

	sleep 60 
	r=$(($r + 1))
  done
done

#
# Ansible will take care of key exchange and learning the host fingerprints, but for the first time we need
# to disable host key checking. 

#
if [[ $execution -eq 1 ]] ; then
  ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook  /home/opc/playbooks/site.yml -i /home/opc/playbooks/inventory
else

	cat <<- EOF > /etc/motd
	At least one of the cluster nodes has been innacessible during installation. Please validate the hosts and re-run: 
	ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook /home/opc/playbooks/site.yml -i /home/opc/playbooks/inventory
EOF

fi 
