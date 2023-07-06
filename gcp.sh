sudo rm /home/$USER/.kube/config


 # Git clone the repository
sudo git clone --branch PL-3051 https://github.com/CloudifyLabs/Cloudifytests_charts.git

# # Change into the cloned repository directory
sudo chmod 777 Cloudifytests_charts
cd Cloudifytests_charts

# # Check if the operating system is Amazon Linux
if [[ "$(cat /etc/os-release | grep -o 'NAME=\"Amazon Linux\"')" == 'NAME="Amazon Linux"' ]]; then
  # Install openssl if it is not already installed
  if ! command -v openssl &> /dev/null; then
    sudo yum install -y openssl
  fi
fi

# Check if Helm is installed and install it if it's not
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install eksctl
if ! command -v eksctl &> /dev/null; then
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
fi

az login
