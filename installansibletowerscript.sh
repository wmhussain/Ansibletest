#!/bin/sh
## Argument 1 will be password for Ansible Tower UI Admin  ##
## Argument 2 will be password for Database Admin  ##
## Argument 3 will be username for Client VMs  ##
## Argument 4 will be password for Client Vms  ##
## Argument 5 will be IP address of client VM 1 ##
## Argument 6 will be IP address of client VM 2 ##
## Argument 6 will be Resource Group Name ##
## To execute this script run sudo su -c'sh installAnsibleTowerScript.sh Ansibleadminpassword Databaseadminpassword ClientVMsUsername ClientVMsPassword ClientVm01IP ClientVm02IP'  ##

yum clean all
### Installing Required Dependencies ###
########################################

yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y python-setuptools python-daemon pystache python-ecdsa python-paramiko python-keyczar python-crypto python-httplib git wget sshpass python-pip python-wheel openssl-devel gcc

pip install --upgrade pip
pip install "pywinrm>=0.2.2"
pip install setuptools --upgrade 
pip install azure==2.0.0rc6 --upgrade

#Disable SSH Copy prompt#
echo "StrictHostKeyChecking no" >> /etc/ssh/sshd_config

## The following code generates SSH Keys and copies it to other hosts ##  
ssh-keygen -f $HOME/.ssh/id_rsa -t rsa -b 4096 -N ''
sshpass -p '$4' ssh-copy-id $3@$5

#### Install Ansible ########
yum install ansible -y
#############################

wget http://releases.ansible.com/ansible-tower/setup/ansible-tower-setup-latest.tar.gz
tar xvzf ansible-tower-setup*
cd ansible-tower-setup*

# Relax the min var requirements
sed -i -e "s/10000000000/100000000/" roles/preflight/defaults/main.yml
# Allow sudo with out tty
sed -i -e "s/Defaults    requiretty/Defaults    \!requiretty/" /etc/sudoers

cat <<EOF > inventory

[tower]

localhost ansible_connection=local

[database]
[all:vars]

admin_password="$1"

pg_host=''
pg_port=''

pg_database='awx'
pg_username='awx'
pg_password="$2"

rabbitmq_port=5672
rabbitmq_vhost=tower
rabbitmq_username=tower
rabbitmq_password="$2"
rabbitmq_cookie=rabbitmqcookie

# Needs to be true for fqdns and ip addresses
rabbitmq_use_long_name=false

EOF

# Changing hostname of Ansible Tower VM #
hostnamectl set-hostname tower

ANSIBLE_BECOME_METHOD=’sudo’ 
ANSIBLE_BECOME=True


### Install Ansible Tower ###
#if ( bash setup.sh );
#    then
#     echo "Tower installed successfully"
#    else
#      exit 2
#    fi 
mkdir -p /var/log/tower
bash setup.sh
grep -Po '(?<=failed=).*' /var/log/tower/setup-*.log > x
i=$(head -c 1  x)
if ( $i -ne 0 );
then
exit 2
fi
### Disable SELinux ###
setenforce 0
sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
chmod -R o+rX /var/lib/awx/public
sed 's/lazy-apps/lazy-apps -b 32768/' /etc/supervisord.d/tower.ini > /etc/supervisord.d/tower1.ini
mv /etc/supervisord.d/tower.ini /etc/supervisord.d/tower_org.ini
mv /etc/supervisord.d/tower1.ini /etc/supervisord.d/tower.ini

####Licensing Ansible Tower###########s
url="https://$7/api/v1/config/"
sleep 10
curl -k -H "Content-Type: application/json" -X POST -u admin:$1 -d '{"eula_accepted" : "true", "company_name": "Spektra systems", "contact_email": "mazhar.warsi@spektrasystems.com", "contact_name": "Mazhar Warsi", "hostname": "6b654363fd20407b8808883cf8c421c2", "instance_count": 10, "license_date": 2123757894, "license_key": "23bacea857aedc64b97cce6db5f6e06e31903b712e3f843c3a1d50984ca52852", "license_type": "basic", "subscription_name": "Ansible Tower by Red Hat, Self-Support (10 Managed Nodes)"}' $url
sleep 60
####################################################

###############Restart Ansible Tower Service#################
if ( ansible-tower-service restart );
then 
echo "service started sucessfully"
else 
exit 2
fi

exit 0
