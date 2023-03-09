# #!/bin/bash



 # Git clone the repository
sudo git clone  https://github.com/CloudifyLabs/Cloudifytests_charts.git

# # Change into the cloned repository directory
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

# Install eksctl
if ! command -v eksctl &> /dev/null; then
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
fi

aws configure



echo -e "\nKindly check all the details in cluster.yaml If you want to create the cluster.\n"
read -p "Enter Yes to create cluster using the cluster.yaml or Enter No to skip this step : " flag

if [[ $flag == "yes" || $flag == "Yes" ]]; then
  eksctl create cluster -f cluster.yaml

else 
  echo "This application will be deployed on your own Cluster."
  echo -e "Enter your cluster details.\n"
  
  read -p "Enter your previously created cluster name : " p_cluster_name

  read -p "Enter your AWS region where you have previously created the cluster : " p_aws_region
  aws eks update-kubeconfig --name $p_cluster_name --region $p_aws_region
fi

flag=true
# # Define the name of the namespace as input by the user
echo -e "\nConditions for Namespace name.\n- Capital letters are not allowed. \n- Should start and end with digits or alphabet. \n- Spaces are not allowed. \n- Allowed alphabets , digits and - \n- Minimum 3 and Maximum 20 characters.\n"
while $flag :
do
read -p "Enter the Namespace name: " org_name
firstChar=${org_name:0:1}
lastChar=${org_name: -1}
len=`expr length "$org_name"`
if [[ $org_name == *['!'@#\$%^\&*()_+]* || "$org_name" =~ [[:upper:]] || "$firstChar"  == *['!'@#\$%^\&*()_+-]* || "$lastChar"  == *['!'@#\$%^\&*()_+-]* || $org_name = *[[:space:]]* || $firstChar = *[[:space:]]* || $lastChar = *[[:space:]]* || $len -lt 3 || $len -gt 20 ]]
  then
    echo "Invalid Namespace name : $org_name. Follow the conditions above conditions for namespace name."
  else 
    flag=false
    echo -e "\nYour Namespace name is : $org_name\n"
    break
fi
done


# Define the AWS access key and secret key as input by the user
read -p "Enter your AWS access key: " aws_key
echo -e "\nYour AWS access key is : $aws_key\n"
read -p "Enter your AWS secret key: " aws_secret_key
echo -e "\nYour AWS secret access key is : $aws_secret_key\n"

# Define the base URL and ingress host as input by the user


# Define the AWS S3 bucket name and default region as input by the user
read -p "Enter your AWS default region: " aws_region
echo -e "\nYour AWS default region is : $aws_region\n"

flag2=true

echo -e "\nConditions for Bucket name.\n- Capital letters are not allowed. \n- Should start and end with digits or alphabet. \n- Spaces are not allowed. \n- Allowed alphabets , digits and - \n- Minimum 3 and Maximum 63 characters.\n"

while $flag2 :
do
read -p "Enter the Bucket name: " s3_bucket
firstChar2=${s3_bucket:0:1}
lastChar2=${s3_bucket: -1}
len2=`expr length "$s3_bucket"`
if [[ $s3_bucket == *['!'@#\$%^\&*()_+]* || "$s3_bucket" =~ [[:upper:]] || "$firstChar2"  == *['!'@#\$%^\&*()_+-]* || "$lastChar2"  == *['!'@#\$%^\&*()_+-]* || $s3_bucket = *[[:space:]]* || $firstChar = *[[:space:]]* || $lastChar = *[[:space:]]* || $len2 -lt 3 || $len2 -gt 63 ]]
  then
    echo "Invalid Namespace name : $s3_bucket. Follow the conditions above conditions for namespace name."
  else 
    flag=false
    if [[ -n "$s3_bucket" ]] 
    then
      if [[ $aws_region == "us-east-1" ]]
      then 
        aws s3api create-bucket --bucket=$s3_bucket --region=$aws_region
        echo -e "\nYour Bucket created with name $s3_bucket\n"
      else
        aws s3api create-bucket --bucket=$s3_bucket --create-bucket-configuration LocationConstraint=$aws_region #--region=$aws_region
        echo -e "\nYour Bucket created with name $s3_bucket\n"
      fi
    else 
      if [[ $aws_region == "us-east-1" ]]
      then 
        aws s3api create-bucket --bucket="session-$org_name" --region=$aws_region
        echo -e "\nYour Bucket created as same as namespace name $org_name\n"
      else
        aws s3api create-bucket --bucket="session-$org_name" --create-bucket-configuration LocationConstraint=$aws_region #--region=$aws_region
        echo -e "\nYour Bucket created as same as namespace name $org_name\n"
      fi
    fi
      break
  fi
  done




# Define the AWS ECR image repository and tag as input by the user
read -p "Enter your AWS ECR image repository: " ecr_repo
echo -e "\nYour AWS ECR image repository tag is : $ecr_repo\n"

read -p "Enter your cluster name: " cluster_name
echo -e "\nYour EKS Cluster name is : $cluster_name\n"


# Update KubeConfig
aws eks update-kubeconfig --name $cluster_name --region $aws_region


# Create a namespace with the name entered by the user
kubectl create namespace $org_name


helm repo add autoscaler https://kubernetes.github.io/autoscaler

helm install auto-scaler autoscaler/cluster-autoscaler --set  'autoDiscovery.clusterName'=$cluster_name \
--set awsRegion=$aws_region




# Apply the Helm chart using the inputs provided by the user
helm template . \
--set s3microservices.AWS_ACCESS_KEY_ID=$aws_key \
--set s3microservices.AWS_SECRET_ACCESS_KEY=$aws_secret_key \
--set urls.BASE_URL=http://cloudifytests-session-be.$org_name.svc.cluster.local:5000/ \
--set s3microservices.S3_BUCKET=$s3_bucket \
--set s3microservices.AWS_DEFAULT_REGION=$aws_region \
--set sessionbe.serviceAccountName=$org_name --set nginxhpa.metadata.namespace=$org_name \
--set be.ORG_NAME=$org_name \
--set sessionbe.image.repository="$ecr_repo:sessionbe_latest" \
--set sessionUi.image.repository="$ecr_repo" \
--set sessionUi.image.tag=sessionui_latest \
--set smcreate.image.repository="$ecr_repo:smcreate_latest" \
--set smdelete.image.repository="$ecr_repo:smdelete_latest" \
--set sessionmanager.AWS_ECR_IMAGE=public.ecr.aws/r2h8i7a4 \
--set smlogsvalues.ORG_NAME=$org_name \
--set behpa.metadata.namespace=$org_name --set sessionManagaerhpa.metadata.namespace=$org_name \
--set role.metadata.namespace=$org_name --set roleBinding.metadata.namespace=$org_name \
--set smcreatehpa.metadata.namespace=$org_name --set smdeletehpa.metadata.namespace=$org_name \
--set serviceaccount.metadata.namespace=$org_name \
--set roleBinding.subjects.namespace=$org_name | kubectl create --namespace $org_name -f -



# Get the hostname of the service in the specified namespace
hostname=""
for i in {1..5}; do
  hostname=$(kubectl get svc -n $org_name cloudifytests-nginx -o 'go-template={{range .status.loadBalancer.ingress}}{{.hostname}}{{end}}')
  if [[ -n "$hostname" ]]; then
    break
  else
    echo "Creating your environment..."
    sleep 30
  fi
done

if [[ -z "$hostname" ]]; then
  echo "Failed to get the hostname."
  exit 1
fi
echo "Wait for 2 minutes and use this hostname to access the application"
echo "The hostname of service is: $hostname"
