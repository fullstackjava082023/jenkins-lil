#!/bin/bash

# LOGFILE="/var/log/jenkins-startup.log"
# exec > >(tee -a ${LOGFILE} )
# exec 2> >(tee -a ${LOGFILE} >&2)

echo "Starting Jenkins setup..."

# Add Jenkins repository for Ubuntu
echo "Adding Jenkins repository..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and upgrade system
echo "Updating package lists..."
sudo apt-get update
echo "Upgrading packages..."
sudo apt-get upgrade -y

# Install dependencies and Jenkins
echo "Installing OpenJDK 17..."
sudo apt-get install -y openjdk-17-jre
echo "Installing Jenkins, Docker, and Git..."
sudo apt-get install -y jenkins docker.io git nginx


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

# # Allow firewall on port 8080
# echo "Configuring firewall..."
# sudo ufw allow 8080
# sudo ufw reload

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

