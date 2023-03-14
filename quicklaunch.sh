#!/bin/bash



#Remove kube config file

sudo rm /home/$USER/.kube/config


 # Git clone the repository
sudo git clone --branch PL-2338 https://github.com/CloudifyLabs/Cloudifytests_charts.git

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
  echo -e "\nEnter your cluster details\n"
  read -p "Enter the name of the cluster" $cluster_name2
  read -p "Enter your AWS default region where you want to create your cluster" $aws_region2
  read -p "Enter the name of node group" $ng_name
  read -p "Enter the max no .of nodes" $max_node
  read -p "Enter the min no .of nodes" $min_node
  
  set -e
  eksctl create cluster --name $cluster_name2  --region $aws_region2 --nodegroup-name $ng_name --node-type t3.xlarge --nodes 3 --nodes-min $min_node --nodes-max $max_node
  echo -e "\nYour Cluster will be created with name $cluster_name2 in AWS region $aws_region2\n"
  #eksctl create cluster -f cluster.yaml

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
if [[ $org_name == *['!'@#\$%^\&*()_+?~/=]* || $org_name =~ "." || $org_name =~ "<" || $org_name =~ "," || $org_name =~ ">" || $org_name =~ "|" || $org_name =~ ";" || $org_name =~ ":" || $org_name =~ "{" || $org_name =~ "}" || $org_name =~ "[" || $org_name =~ "]" || $org_name =~ "'" || $org_name =~ [[:upper:]] || $firstChar == *['!'@#\$%^\&*()_+?=-]* || $lastChar == *['!'@#\$%^\&*()_+?=-]* || $org_name = *[[:space:]]* || $firstChar = *[[:space:]]* || $lastChar = *[[:space:]]* || $len -lt 3 || $len -gt 20 ]]
  then
    echo "Invalid Namespace name : $org_name. Follow the conditions above conditions for namespace name."
  else 
    flag=false
    echo -e "\nYour Namespace name is : $org_name\n"
    break
fi
done




flag2=true


while $flag2 :
do

# Define the AWS access key and secret key as input by the user

read -p "Enter your AWS access key: " aws_key
echo -e "\nYour AWS access key is : $aws_key\n"
read -p "Enter your AWS secret key: " aws_secret_key
echo -e "\nYour AWS secret access key is : $aws_secret_key\n"

# Define the base URL and ingress host as input by the user


# Define the AWS S3 bucket name and default region as input by the user
read -p "Enter your AWS default region: " aws_region
echo -e "\nYour AWS default region is : $aws_region\n"
echo -e "\nConditions for Bucket name.\n- Capital letters are not allowed. \n- Should start and end with digits or alphabet. \n- Spaces are not allowed. \n- Allowed alphabets , digits and - \n- Minimum 3 and Maximum 63 characters.\n"

read -p "Enter the Bucket name: " s3_bucket
firstChar2=${s3_bucket:0:1}
lastChar2=${s3_bucket: -1}
len2=`expr length "$s3_bucket"`
if [[ $s3_bucket == *['!'@#\$%^\&*()_+?~/=]* || $s3_bucket =~ "," || $s3_bucket =~ "." || $s3_bucket =~ "<" || $s3_bucket =~ ">" || $s3_bucket =~ "|" || $s3_bucket =~ ";" || $s3_bucket =~ ":" || $s3_bucket =~ "{" || $s3_bucket =~ "}" || $s3_bucket =~ "[" || $s3_bucket =~ "]" || $s3_bucket =~ "'" || $s3_bucket =~ [[:upper:]] || $firstChar2 == *['!'@#\$%^\&*()_+?=-]* || $lastChar2 == *['!'@#\$%^\&*()_+?=-]* || $s3_bucket = *[[:space:]]* || $firstChar2 = *[[:space:]]* || $lastChar2 = *[[:space:]]* || $len2 -lt 3 || $len2 -gt 63 ]] 
  then
    echo "Invalid S3 Bucket name : $s3_bucket. Follow the conditions above conditions for namespace name."
  else 
    #flag2=true
    if [[ -n "$s3_bucket" ]] 
    then
      if [[ $aws_region == "us-east-1" ]]
      then 
         aws s3 ls $s3_bucket
         var=$(echo $?)
         if [[ "$var" -eq 0 ]]
         then
          echo -e "\nBucket already exists or an error occurred.\nPlease try with another name.\n"
          echo -e "\nEnter AWS Access key , Secret access key and AWS Region again.\n"
          flag2=true
        else
          aws s3api create-bucket --bucket=$s3_bucket --region=$aws_region
          echo -e "\nBucket created with name $s3_bucket"
          break
        fi
      else
       aws s3 ls $s3_bucket
       var2=$(echo $?)
       #var2=$(aws s3api create-bucket --bucket=$s3_bucket --create-bucket-configuration LocationConstraint=$aws_region)
       #echo "$var2 1"
       if [[ "$var2" -eq 0 ]]
        then
        echo -e "\nBucket already exists or an error occurred.\nPlease try with another name.\n"
        echo -e "\nEnter AWS Access key , Secret access key and AWS Region again.\n"
        flag2=true
      else
       aws s3api create-bucket --bucket=$s3_bucket --create-bucket-configuration LocationConstraint=$aws_region
       echo -e "\nBucket created with name $s3_bucket"
       break
       fi
     fi
    fi
     # break
  fi
  done




# Define the AWS ECR image repository and tag as input by the user
read -p "Enter your AWS ECR image repository: " ecr_repo
echo -e "\nYour AWS ECR image repository tag is : $ecr_repo\n"

read -p "Enter the tag for sessionbe: " sessionbe_tag
echo -e "\nYour sessiobe tag is : $sessionbe_tag\n"

read -p "Enter the tag for sessionui: " sessionui_tag
echo -e "\nYour sessionui tag is : $sessionui_tag\n"

read -p "Enter the tag for smcreate: " smcreate_tag
echo -e "\nYour smcreate tag tag is : $smcreate_tag\n"

read -p "Enter the tag for smdelete: " smdelete_tag
echo -e "\nYour smdelete tag is : $smdelete_tag\n"

read -p "Enter your cluster name: " cluster_name
echo -e "\nYour EKS Cluster name is : $cluster_name\n"


# Update KubeConfig
aws eks update-kubeconfig --name $cluster_name --region $aws_region

 
# Create a namespace with the name entered by the user
kubectl create namespace $org_name


helm repo add autoscaler https://kubernetes.github.io/autoscaler

helm install auto-scaler autoscaler/cluster-autoscaler --set  'autoDiscovery.clusterName'=$cluster_name \
--set awsRegion=$aws_region

kubectl patch deploy auto-scaler-aws-cluster-autoscaler --patch '{"spec": {"template": {"spec": {"containers": [{"name": "aws-cluster-autoscaler", "command": ["./cluster-autoscaler","--cloud-provider=aws","--namespace=default","--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/$cluster_name","--scale-down-unneeded-time=1m","--logtostderr=true","--stderrthreshold=info","--v=4"]}]}}}}' 




# Apply the Helm chart using the inputs provided by the user
helm template . \
--set s3microservices.AWS_ACCESS_KEY_ID=$aws_key \
--set s3microservices.AWS_SECRET_ACCESS_KEY=$aws_secret_key \
--set urls.BASE_URL=http://cloudifytests-session-be.$org_name.svc.cluster.local:5000/ \
--set s3microservices.S3_BUCKET=$s3_bucket \
--set s3microservices.AWS_DEFAULT_REGION=$aws_region \
--set sessionbe.serviceAccountName=$org_name --set nginxhpa.metadata.namespace=$org_name \
--set be.ORG_NAME=$org_name \
--set sessionbe.image.repository="$ecr_repo:sessionbe_$sessionbe_tag" \
--set sessionUi.image.repository="$ecr_repo" \
--set sessionUi.image.tag=sessionui_$sessionui_tag \
--set smcreate.image.repository="$ecr_repo:smcreate_$smcreate_tag" \
--set smdelete.image.repository="$ecr_repo:smdelete_$smdelete_tag" \
--set sessionmanager.AWS_ECR_IMAGE=public.ecr.aws/r2h8i7a4 \
--set smlogsvalues.ORG_NAME=$org_name \
--set behpa.metadata.namespace=$org_name --set sessionManagaerhpa.metadata.namespace=$org_name \
--set role.metadata.namespace=$org_name --set roleBinding.metadata.namespace=$org_name \
--set smcreatehpa.metadata.namespace=$org_name --set smdeletehpa.metadata.namespace=$org_name \
--set serviceaccount.metadata.namespace=$org_name \
--set roleBinding.subjects.namespace=$org_name | kubectl create --namespace $org_name -f -

#Roll back Code

echo -e "\nWait for sometime.\n"
sleep 30
var_status=$(kubectl delete pods --field-selector status.phase=Pending -n $org_name)
if [[ "$var_status" =~ "No resources found" ]]
then
var=$(kubectl get ns)
if [[ -z "$var" ]]
then 
  echo -e "\nIncorrect details problem creating your environment.Please try with correct details. \n\n" 
else
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

echo "The hostname of service is: $hostname"
echo "Wait for 2 minutes and use this hostname to access the application"
fi
else
#echo -e "$var"
echo -e "\nSomething went wrong Wait for sometime for the  namespace to be deleted\n"
kubectl delete ns $org_name
echo -e "\nNamespace $org_name deleted\nTry to run the command again\n"
fi

