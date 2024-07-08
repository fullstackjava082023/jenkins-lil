#!/bin/bash
# vi: ft=bash


# # redirect stdout and stderr to a log file
# LOGFILE="/var/log/jenkins-startup.log"
# exec > >(tee -a ${LOGFILE} )
# exec 2> >(tee -a ${LOGFILE} >&2)

echo "# $(date) Installation is starting."
echo "Starting Jenkins setup..."

# Add Jenkins repository for Ubuntu
echo "Adding Jenkins repository..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and upgrade system
echo "Updating package lists..."
sudo apt-get update -y
echo "Upgrading packages..."
sudo apt-get upgrade -y



# Uncomment the following line if you are using this script
# as user data for an EC2 instance on AWS.
# Output from the installation will be written to /var/log/user-data.log
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


# Install dependencies and Jenkins
# install java, nginx, and jenkins
echo "Installing OpenJDK 17..."
sudo apt-get install -y openjdk-17-jre
echo "Installing Jenkins, Docker, and Git..."
sudo apt-get install docker.io git nginx -y


apt update -y
apt-get -y upgrade

apt-get -y install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

apt-get -y install jenkins

# configure jenkins
echo "# $(date) Configure Jenkins..."

## skip the installation wizard at startup
echo "# $(date) Skip the installation wizard on first boot..."
echo "JAVA_ARGS=\"-Djenkins.install.runSetupWizard=false\"" >> /etc/default/jenkins

## download the list of plugins
echo "# $(date) Download the list of plugins..."
wget https://raw.githubusercontent.com/jenkinsci/jenkins/master/core/src/main/resources/jenkins/install/platform-plugins.json

## get the suggested plugins
echo "# $(date) Use the keyword 'suggest' to find the suggested plugins in the list..."
grep suggest platform-plugins.json | cut -d\" -f 4 | tee suggested-plugins.txt

## download the plugin installation tool
echo "# $(date) Download the plugin installation tool"
wget https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar
## run the plugin installation tool
echo "# $(date) Run the plugin installation tool..."
/usr/bin/java -jar ./jenkins-plugin-manager-2.13.0.jar \
	--verbose \
    --plugin-download-directory=/var/lib/jenkins/plugins \
    --plugin-file=./suggested-plugins.txt >> /var/log/plugin-installation.log

## because the plugin installation tool runs as root, ownership on
## the plugin dir needs to be changed back to jenkins:jenkins
## otherwise, jenkins won't be able to install the plugins
echo "# $(date) Update the permissions on the plugins directory..."
chown -R jenkins:jenkins /var/lib/jenkins/plugins

# configure nginx
echo "# $(date) Configure NGINX..."
unlink /etc/nginx/sites-enabled/default

tee /etc/nginx/conf.d/jenkins.conf <<EOF
upstream jenkins {
    server 127.0.0.1:8080;
}

server {
    listen 80 default_server;
    listen [::]:80  default_server;
    location / {
        proxy_pass http://jenkins;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "# $(date) Reload NGINX to pick up the new configuration..."
systemctl reload nginx

# # install docker
# echo "# $(date) Install docker..."
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
#     gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
echo "Installing Docker..."
apt-get -y install docker-ce docker-ce-cli containerd.io
docker run hello-world

systemctl enable docker.service
systemctl enable containerd.service

usermod -aG docker ubuntu
usermod -aG docker jenkins

echo "# $(date) Restart Jenkins..."
systemctl restart jenkins

echo "# $(date) Copy the initial admin password to the root user's home directory..."
cp /var/lib/jenkins/secrets/initialAdminPassword ~

clear
echo "Installation is complete."

echo "# Open the URL for this server in a browser and log in with the following credentials:"
echo
echo
echo "    Username: admin"
echo "    Password: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo
echo

