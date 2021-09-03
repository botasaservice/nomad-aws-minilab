#!/bin/bash
# 
# user-data script for deploying Nomad on Amazon Linux 2
# 
# Using the user-data / cloud init ensures we don't run twice
#  

# Update system and install dependencies

sudo yum update -y
sudo yum install unzip curl vim jq -y
sudo yum install amazon-ecr-credential-helper -y

# make an archive folder to move old binaries into
if [ ! -d /tmp/archive ]; then
  sudo mkdir /tmp/archive/
fi

# Install docker
sudo yum install -y git
sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo chkconfig docker on

#install ecr-helper
mkdir /root/.docker/
sudo rm -rf /root/.docker/config.json
sudo tee -a /root/.docker/config.json <<EOF
{
        "credsStore": "ecr-login"
}
{
        "credHelpers": {
                "public.ecr.aws": "ecr-login",
                "960542190111.dkr.ecr.ap-northeast-1.amazonaws.com": "ecr-login"
        }
}
EOF

# install .aws default directory
sudo mkdir /root/.aws/
sudo rm -rf /root/.aws/config
sudo rm -rf /root/.aws/credentials
sudo tee -a /root/.aws/config <<EOF
[default]
region = ap-northeast-1
EOF

#create nomad task with
sudo tee -a /root/.aws/config <<EOF
[default]
aws_access_key_id = XXX
aws_secret_access_key = XXX
EOF

#create system prune
sudo tee -a /root/.aws/crontab <<EOF
0 3 * * * /usr/bin/docker system prune -f
EOF

sudo crontab /root/.aws/crontab

sudo systemctl restart docker

# Install Nomad
#NOMAD_VERSION=1.0.4
NOMAD_VERSION=1.1.4
sudo curl -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip
if [ ! -d nomad ]; then
  sudo unzip nomad.zip
fi
if [ ! -f /usr/bin/nomad ]; then
  sudo install nomad /usr/bin/nomad
fi
if [ -f /tmp/archive/nomad ]; then
  sudo rm /tmp/archive/nomad
fi
sudo mv /tmp/nomad /tmp/archive/nomad
sudo mkdir -p /etc/nomad.d
sudo chmod a+w /etc/nomad.d

# Nomad config file copy
sudo mkdir -p /tmp/nomad
sudo curl https://raw.githubusercontent.com/botasaservice/nomad-aws-minilab/master/conf/nomad/server.hcl -o /tmp/nomad/server.hcl
sudo cp /tmp/nomad/server.hcl /etc/nomad.d/server.hcl

# Nomad dokcer file copy docker-auth.json
sudo curl https://raw.githubusercontent.com/botasaservice/nomad-aws-minilab/master/conf/nomad/docker-auth.json -o /tmp/nomad/docker-auth.json
sudo cp /tmp/nomad/docker-auth.json /etc/docker-auth.json

# Install Consul
#CONSUL_VERSION=1.9.4
CONSUL_VERSION=1.10.2

sudo curl -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip > consul.zip
if [ ! -d consul ]; then
  sudo unzip consul.zip
fi
if [ ! -f /usr/bin/consul ]; then
  sudo install consul /usr/bin/consul
fi
if [ -f /tmp/archive/consul ]; then
  sudo rm /tmp/archive/consul
fi
sudo mv /tmp/consul /tmp/archive/consul
sudo mkdir -p /etc/consul.d
sudo chmod a+w /etc/consul.d

# Consul config file copy
sudo mkdir -p /tmp/consul
sudo curl https://raw.githubusercontent.com/botasaservice/nomad-aws-minilab/master/conf/consul/server.hcl -o /tmp/consul/server.hcl
sudo cp /tmp/consul/server.hcl /etc/consul.d/server.hcl

for bin in cfssl cfssl-certinfo cfssljson
do
  echo "$bin Install Beginning..."
  if [ ! -f /tmp/${bin} ]; then
    curl -sSL https://pkg.cfssl.org/R1.2/${bin}_linux-amd64 > /tmp/${bin}
  fi
  if [ ! -f /usr/local/bin/${bin} ]; then
    sudo install /tmp/${bin} /usr/local/bin/${bin}
  fi
done
cat /root/.bashrc | grep  "complete -C /usr/bin/nomad nomad"
retval=$?
if [ $retval -eq 1 ]; then
  nomad -autocomplete-install
fi



# Install Ansible for config management
sudo amazon-linux-extras install ansible2 -y

# Form Consul Cluster
ps -C consul
retval=$?
if [ $retval -eq 0 ]; then
  sudo killall consul
fi
sudo nohup consul agent --config-file /etc/consul.d/server.hcl &>$HOME/consul.log &

# Form Nomad Cluster
ps -C nomad
retval=$?
if [ $retval -eq 0 ]; then
  sudo killall nomad
fi
sudo nohup nomad agent -config /etc/nomad.d/server.hcl &>$HOME/nomad.log &

# Bootstrap Nomad and Consul ACL environment

# Write anonymous policy file 

sudo tee -a /tmp/anonymous.policy <<EOF
namespace "*" {
  policy       = "write"
  capabilities = ["alloc-node-exec"]
}
agent {
  policy = "write"
}
operator {
  policy = "write"
}
quota {
  policy = "write"
}
node {
  policy = "write"
}
host_volume "*" {
  policy = "write"
}
EOF

#new versions

sudo usermod -a -G docker ec2-user
sudo groupadd docker
sudo usermod -aG docker ${USER}
