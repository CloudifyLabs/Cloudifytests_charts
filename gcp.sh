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


#Cluster details.

read -p "Enter Yes to create cluster  or Enter No if you already have a GKE cluster : " flag
if [[ $flag == "yes" || $flag == "Yes" ]]; then
   echo -e "\nEnter your cluster details\n"

   

   read -p "Enter the name of the cluster (default name - cloudifytests): " CLUSTER_NAME
   if [[ -z $CLUSTER_NAME ]]
   then
    CLUSTER_NAME=cloudifytests
   fi
   echo -e "\nYour Cluster Name will be : $CLUSTER_NAME\n"


   read -p "Enter your gcloud region where you want to create your cluster (default gcloud region - us-central1 ): " ZONE 
   if [[ -z $ZONE ]]
   then
    ZONE=us-central1
   fi
   echo -e "\nYour gcloud region will be : $ZONE\n"

   read -p "Enter your gcloud 1st node-pool name (default node-pool name - userapp ): " NODE_POOL_1
   if [[ -z $NODE_POOL_1 ]]
   then
    NODE_POOL_1=userapp
   fi
   echo -e "\nYour gcloud 1st node-pool name will be : $NODE_POOL_1\n"

   read -p "Enter your gcloud 1st node-pool name (default node-pool name - browsersession ): " NODE_POOL_2
   if [[ -z $NODE_POOL_2 ]]
   then
    NODE_POOL_2=browsersession
   fi
   echo -e "\nYour gcloud 2nd node-pool name will be : $NODE_POOL_2\n"


fi
read -p "Enter your-project-id : " PROJECT_ID

gcloud config set project $PROJECT_ID

gcloud services enable container.googleapis.com



# Create the cluster
gcloud container clusters create "$CLUSTER_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --machine-type "$MACHINE_TYPE" \
  --enable-autoscaling \
  --num-nodes "$NUM_NODES_1" \
  --node-taints userapp=true:NoSchedule

# Create the second node group
gcloud container node-pools create $NODE_POOL_2 \
  --cluster "$CLUSTER_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --machine-type "$MACHINE_TYPE" \
  --enable-autoscaling \
  --num-nodes "$NUM_NODES_2" \
  --node-taints browsersession=true:NoSchedule


 kubectl patch deployment coredns -p '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"userapp","value":"true"}]}}}}' -n kube-system

 #helm repo add autoscaler https://kubernetes.github.io/autoscaler

 #helm install my-release autoscaler/cluster-autoscaler --set  'autoDiscovery.clusterName'=$CLUSTER_NAME  --set tolerations[0].key=userapp --set-string tolerations[0].value=true --set tolerations[0].operator=Equal --set tolerations[0].effect=NoSchedule  --set awsRegion=$aws_region2
  
  
 kubectl apply -f metrics-deployment.yml  


