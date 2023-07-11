#!/bin/bash



#Remove kube config file

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

echo -e "\nKindly check all the details in cluster.yaml If you want to create the cluster.\n"
read -p "Enter Yes to create cluster using the cluster.yaml or Enter No to skip this step : " flag

if [[ $flag == "yes" || $flag == "Yes" ]]; then
   echo -e "\nEnter your cluster details\n"

   read -p "Enter the name of the cluster (default name - marketplace): " cluster_name
   if [[ -z $cluster_name ]]
   then
    cluster_name=marketplace
   fi
   echo -e "\nYour Cluster Name will be : $cluster_name\n"


   read -p "Enter your AZURE Cloud Region where you want to create your cluster (default AWS region - EAST US): " aws_region
   if [[ -z $aws_region ]]
   then
    aws_region=EAST US
   fi
   echo -e "\nYour AZURE region will be : $aws_region\n"

   read -p "Enter your Resource group Name: " resource_group
   echo -e "\nYour AZURE resource group will be : $resource_group\n"

   read -p "Enter your azure cloud 1st node-pool name (default node-pool name - marketplace-userapp ): " NODE_POOL_1
   if [[ -z $NODE_POOL_1 ]]
   then
    NODE_POOL_1=marketplace-userapp
   fi
   echo -e "\nYour 1st node-pool name will be : $NODE_POOL_1\n"

   read -p "Enter your  2nd node-pool name (default node-pool name - marketplace-browsersession ): " NODE_POOL_2
   if [[ -z $NODE_POOL_2 ]]
   then
    NODE_POOL_2=marketplace-browsersession
   fi
   echo -e "\nYour 2nd node-pool name will be : $NODE_POOL_2\n"

fi

   # Create the cluster
   az aks create --resource-group $resource_group --name $cluster_name --generate-ssh-keys

   az aks nodepool add --resource-group $resource_group --cluster-name $cluster_name --name  $NODE_POOL_1 --node-vm-size Standard_D4s_v3 --node-count 1 --node-taints $NODE_POOL_1=true:NoSchedule \
   #az aks nodepool add --resource-group $resource_group --cluster-name $cluster_name --name  $NODE_POOL_2 --node-vm-size Standard_D4s_v3 --node-count 1 --node-taints $NODE_POOL_2=true:NoSchedule \

   az aks get-credentials --resource-group $resource_group --name $cluster_name
   kubectl patch deployment coredns -p '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"marketplace-userapp","value":"true"}]}}}}' -n kube-system
   kubectl apply -f metrics-deployment.yml
  #  read -p "Enter the min no .of nodes : " min_node
  #  if [[ -z $min_node ]]
  #  then
  #   min_node=1
  #  fi
  #  echo -e "\nMinimum nodes will be : $min_node\n"

#    echo -e "\nFor running 2 sessions you need 1 node. Enter the no .of maximum nodes according to your need.\n"
#    read -p "Enter the  no .of maximum nodes (default - 4): " max_node
#    if [[ -z $max_node ]]
#    then
#     max_node=4
#    fi
#    echo -e "\nMaximum nodes will be : $max_node\n"

