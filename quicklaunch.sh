#!/bin/bash



#Remove kube config file

sudo rm /home/$USER/.kube/config


 # Git clone the repository
sudo git clone --branch PL-2540 https://github.com/CloudifyLabs/Cloudifytests_charts.git

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

   read -p "Enter the name of the cluster (default name - marketplace): " cluster_name2
   if [[ -z $cluster_name2 ]]
   then
    cluster_name2=marketplace
   fi
   echo -e "\nYour Cluster Name will be : $cluster_name2\n"


   read -p "Enter your AWS region where you want to create your cluster (default AWS region - us-east-1): " aws_region2
   if [[ -z $aws_region2 ]]
   then
    aws_region2=us-east-1
   fi
   echo -e "\nYour AWS region will be : $aws_region2\n"

#    read -p "Enter the name of node group (default name - worker) : " ng_name
#    if [[ -z $ng_name ]]
#    then
#     ng_name=worker
#    fi
#    echo -e "\nYour NodeGroup Name will be : $ng_name\n"
   
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

 # Generate the cluster.yaml file with the custom name
sudo bash -c "cat <<EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $cluster_name2
  region: $aws_region2
#  version: "1.25"
  


managedNodeGroups:
  - name: marketplace-userapp
    instanceType: t3.xlarge
    minSize: 1
    maxSize: 4
    desiredCapacity: 1
    volumeType: gp3
    volumeSize: 50
    
   # taints:
   #  - key: "marketplace-userapp"
   #     value: "true"
   #     effect: NoSchedule
      
    labels: {role: worker}
    tags:
      nodegroup-role: worker
    iam:
      
      withAddonPolicies:
        externalDNS: true
        certManager: true
        imageBuilder: true
        autoScaler: true
        appMesh: true
        appMeshPreview: true
        ebs: true
        efs: true
        albIngress: true
        xRay: true
        cloudWatch: true
  - name: marketplace-browsersession
    instanceType: c5.large
    minSize: 1
    maxSize: 4
    desiredCapacity: 1
    volumeType: gp3
    volumeSize: 50
   
    
   # taints:
   #   - key: "marketplace-browsersession"
   #     value: "true"
   #     effect: NoSchedule
      
    labels: {role: worker}
    tags:
      nodegroup-role: worker
    iam:
      withAddonPolicies:
        externalDNS: true
        certManager: true
        imageBuilder: true
        autoScaler: true
        appMesh: true
        appMeshPreview: true
        ebs: true
        efs: true
        albIngress: true
        xRay: true
        cloudWatch: true
EOF"

  set -e
  eksctl create cluster -f cluster.yaml
  eksctl create addon --name aws-ebs-csi-driver --cluster $cluster_name2
    aws eks update-kubeconfig --name $cluster_name2 --region $aws_region2
    
    read -p "Enter your AWS Account ID : " aws_account_id

    
    aws eks update-nodegroup-config --cluster-name $cluster_name2  --nodegroup-name marketplace-userapp --region $aws_region2  --taints "addOrUpdateTaints=[{key=marketplace-userapp, value=true, effect=NO_SCHEDULE}]"
 
  aws eks update-nodegroup-config --cluster-name $cluster_name2  --nodegroup-name marketplace-browsersession --region $aws_region2  --taints "addOrUpdateTaints=[{key=marketplace-browsersession, value=true, effect=NO_SCHEDULE}]" 
  

  kubectl patch deployment coredns -p '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"marketplace-userapp","value":"true"}]}}}}' -n kube-system


  
  
  
  helm repo add autoscaler https://kubernetes.github.io/autoscaler
  helm install my-release autoscaler/cluster-autoscaler --set  'autoDiscovery.clusterName'=$cluster_name2  --set tolerations[0].key=marketplace-userapp --set-string tolerations[0].value=true --set tolerations[0].operator=Equal --set tolerations[0].effect=NoSchedule  --set awsRegion=$aws_region2
  
  
  

  kubectl apply -f metrics-deployment.yml
  

  kubectl patch deploy my-release-aws-cluster-autoscaler --patch '{"spec": {"template": {"spec": {"containers": [{"name": "aws-cluster-autoscaler", "command": ["./cluster-autoscaler","--cloud-provider=aws","--namespace=default","--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/'${cluster_name2}'","--scale-down-unneeded-time=1m","--logtostderr=true","--stderrthreshold=info","--v=4"]}]}}}}' 
kubectl patch deployment ebs-csi-controller -p '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"marketplace-userapp","value":"true"}]}}}}' -n kube-system

sudo curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
 aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
 oidc_id=$(aws eks describe-cluster --name $cluster_name2 --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
 echo $oidc_id
 eksctl utils associate-iam-oidc-provider --region=$aws_region2 --cluster=$cluster_name2 --approve
 cat >load-balancer-role-trust-policy.json <<EOF
{
     "Version": "2012-10-17",
     "Statement": [
         {
             "Effect": "Allow",
             "Principal": {
                 "Federated": "arn:aws:iam::$aws_account_id:oidc-provider/oidc.eks.$aws_region2.amazonaws.com/id/$oidc_id"
             },
             "Action": "sts:AssumeRoleWithWebIdentity",
             "Condition": {
                 "StringEquals": {
                     "oidc.eks.$aws_region2.amazonaws.com/id/$oidc_id:aud": "sts.amazonaws.com",
                     "oidc.eks.$aws_region2.amazonaws.com/id/$oidc_id:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                 }
             }
         }
     ]
}
EOF
#sudo chmod 755  /home/$USER/load-balancer-role-trust-policy.json
 aws iam create-role --role-name AmazonEKSLoadBalancerControllerRole --assume-role-policy-document file://"load-balancer-role-trust-policy.json"
 aws iam attach-role-policy --policy-arn arn:aws:iam::$aws_account_id:policy/AWSLoadBalancerControllerIAMPolicy --role-name AmazonEKSLoadBalancerControllerRole
 
 
sudo bash -c "cat <<EOF > aws-load-balancer-controller-service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$aws_account_id:role/AmazonEKSLoadBalancerControllerRole
EOF"
 
 kubectl apply -f aws-load-balancer-controller-service-account.yaml
 helm repo add eks https://aws.github.io/eks-charts
 helm repo update
 helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=$cluster_name2 --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller  --set tolerations[0].key=marketplace-userapp --set-string tolerations[0].value=true --set tolerations[0].operator=Equal --set tolerations[0].effect=NoSchedule  --set awsRegion=us-east-1






else 
  echo -e "\nThis application will be deployed on your own Cluster.\n"
  echo -e "- For this application you need two nodegroups.\n"
  echo -e "- First nodegroup should have 4 Vcpus and other nodegroup should have 2 Vcpus.\n"
  echo -e "- If you dont have the following NodeGroups please create your NodeGroups.\n\n"
  
  read -p "Enter Yes to create NodeGroup or Enter No If you have already created the nodegroup : " flag2
  if [[ $flag2 == "yes" || $flag2 == "Yes" ]]; then 
  echo -e "\nTo create NodeGroup please follow the instructions in the Readme and re-run the command.\n"
  exit 1  
  else
  echo -e "\nEnter your two nodegroups name.\n"
  read -p "Enter your 1st NodeGroup name with 4 Vcpus : " n_ng_1
  echo -e "\nYour 1st NodeGroup name. $n_ng_1\n" 
  read -p "Enter your 2nd NodeGroup name with 2 Vcpus : " n_ng_2
  echo -e "\nYour 2nd NodeGroup name. $n_ng_2\n" 

  
   
  echo -e "Enter your cluster details.\n"
  
  read -p "Enter your previously created cluster name : " p_cluster_name

  read -p "Enter your AWS region where you have previously created the cluster : " p_aws_region
  
  read -p "Enter your AWS Account ID : " aws_account_id
  

 aws eks update-kubeconfig --name $p_cluster_name --region $p_aws_region
 
 
  eksctl create addon --name aws-ebs-csi-driver --cluster $p_cluster_name
   aws eks update-nodegroup-config --cluster-name $p_cluster_name  --nodegroup-name $n_ng_1  --taints "addOrUpdateTaints=[{key=marketplace-userapp, value=true, effect=NO_SCHEDULE}]"
 
  aws eks update-nodegroup-config --cluster-name $p_cluster_name  --nodegroup-name $n_ng_2  --taints "addOrUpdateTaints=[{key=marketplace-browsersession, value=true, effect=NO_SCHEDULE}]" 
  
  
  kubectl patch deployment coredns -p '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"marketplace-userapp","value":"true"}]}}}}' -n kube-system
  #kubectl patch deployment ebs-csi-controller -p  '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"userapp","value":"true"}]}}}}' -n kube-system


  helm repo add autoscaler https://kubernetes.github.io/autoscaler

   helm install my-release autoscaler/cluster-autoscaler --set  'autoDiscovery.clusterName'=$p_cluster_name  --set tolerations[0].key=marketplace-userapp --set-string tolerations[0].value=true --set tolerations[0].operator=Equal --set tolerations[0].effect=NoSchedule  --set awsRegion=$p_aws_region
 

  kubectl patch deployment ebs-csi-controller -p  '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"marketplace-userapp","value":"true"}]}}}}' -n kube-system


  
 
  kubectl apply -f metrics-deployment.yml 
  
 kubectl patch deploy my-release-aws-cluster-autoscaler --patch '{"spec": {"template": {"spec": {"containers": [{"name": "aws-cluster-autoscaler", "command": ["./cluster-autoscaler","--cloud-provider=aws","--namespace=default","--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/'${p_cluster_name}'","--scale-down-unneeded-time=1m","--logtostderr=true","--stderrthreshold=info","--v=4"]}]}}}}' 
 
 sudo curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
 aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
 oidc_id=$(aws eks describe-cluster --name $p_cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
 echo $oidc_id
 eksctl utils associate-iam-oidc-provider --region=$p_aws_region --cluster=$p_cluster_name --approve
 cat >load-balancer-role-trust-policy.json <<EOF
{
     "Version": "2012-10-17",
     "Statement": [
         {
             "Effect": "Allow",
             "Principal": {
                 "Federated": "arn:aws:iam::$aws_account_id:oidc-provider/oidc.eks.$p_aws_region.amazonaws.com/id/$oidc_id"
             },
             "Action": "sts:AssumeRoleWithWebIdentity",
             "Condition": {
                 "StringEquals": {
                     "oidc.eks.$p_aws_region.amazonaws.com/id/$oidc_id:aud": "sts.amazonaws.com",
                     "oidc.eks.$p_aws_region.amazonaws.com/id/$oidc_id:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                 }
             }
         }
     ]
}
EOF
# sudo chmod 755  load-balancer-role-trust-policy.json
 aws iam create-role --role-name AmazonEKSLoadBalancerControllerRole --assume-role-policy-document file://"load-balancer-role-trust-policy.json"
 aws iam attach-role-policy --policy-arn arn:aws:iam::$aws_account_id:policy/AWSLoadBalancerControllerIAMPolicy --role-name AmazonEKSLoadBalancerControllerRole
 
 
sudo bash -c "cat <<EOF > aws-load-balancer-controller-service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$aws_account_id:role/AmazonEKSLoadBalancerControllerRole
EOF"
 
 kubectl apply -f aws-load-balancer-controller-service-account.yaml
 helm repo add eks https://aws.github.io/eks-charts
 helm repo update
 helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=$p_cluster_name --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller  --set tolerations[0].key=$n_ng_1 --set-string tolerations[0].value=true --set tolerations[0].operator=Equal --set tolerations[0].effect=NoSchedule  --set awsRegion=us-east-1


  fi
  
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
echo -e "\nConditions for Bucket name.\n- Capital letters are not allowed. \n- Should start and end with digits or alphabet. \n- Spaces are not allowed. \n- Allowed alphabets , digits and - \n- Minimum 3 and Maximum 63 characters.\nDon't use test keyword in the bucket name.\nPlease do not use test keyword in your bucket name.\n"

read -p "Enter the Bucket name: " s3_bucket
firstChar2=${s3_bucket:0:1}
lastChar2=${s3_bucket: -1}
len2=`expr length "$s3_bucket"`
if [[ $s3_bucket == *['!'@#\$%^\&*()_+?~/=]* || $s3_bucket =~ "test" || $s3_bucket =~ "," || $s3_bucket =~ "." || $s3_bucket =~ "<" || $s3_bucket =~ ">" || $s3_bucket =~ "|" || $s3_bucket =~ ";" || $s3_bucket =~ ":" || $s3_bucket =~ "{" || $s3_bucket =~ "}" || $s3_bucket =~ "[" || $s3_bucket =~ "]" || $s3_bucket =~ "'" || $s3_bucket =~ [[:upper:]] || $firstChar2 == *['!'@#\$%^\&*()_+?=-]* || $lastChar2 == *['!'@#\$%^\&*()_+?=-]* || $s3_bucket = *[[:space:]]* || $firstChar2 = *[[:space:]]* || $lastChar2 = *[[:space:]]* || $len2 -lt 3 || $len2 -gt 63 ]] 
  then
    echo -e "\nInvalid S3 Bucket name : $s3_bucket. Follow the conditions above conditions for bucket name.\n"
  else 
    #flag2=true
    if [[ -n "$s3_bucket" ]] 
    then
      if [[ $aws_region == "us-east-1" ]]
      then 
         aws s3 ls $s3_bucket 2>/dev/null
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
       aws s3 ls $s3_bucket 2>/dev/null
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

read -p "Enter your CONTAINER IMAGES repository link for smcreate: " create
echo -e "\nYour AWS ECR image repository tag is : $create\n"

read -p "Enter your CONTAINER IMAGES repository link for sessionUi: " Ui
echo -e "\nYour AWS ECR image repository tag is : $Ui\n"

read -p "Enter your CONTAINER IMAGES repository link for sessionbe: " be
echo -e "\nYour AWS ECR image repository tag is : $be\n"

read -p "Enter your CONTAINER IMAGES repository link for smdelete: " delete
echo -e "\nYour AWS ECR image repository tag is : $delete\n"

# read -p "Enter the tag for sessionbe: " sessionbe_tag
# echo -e "\nYour sessiobe tag is : $sessionbe_tag\n"

# read -p "Enter the tag for sessionui: " sessionui_tag
# echo -e "\nYour sessionui tag is : $sessionui_tag\n"

# read -p "Enter the tag for smcreate: " smcreate_tag
# echo -e "\nYour smcreate tag tag is : $smcreate_tag\n"

# read -p "Enter the tag for smdelete: " smdelete_tag
# echo -e "\nYour smdelete tag is : $smdelete_tag\n"

# read -p "Enter your cluster name: " cluster_name
# echo -e "\nYour EKS Cluster name is : $cluster_name\n"


# Update KubeConfig
# aws eks update-kubeconfig --name $cluster_name2 --region $aws_region2
 
 kubectl patch deployment coredns -p  '{"spec":{"template":{"spec":{"tolerations":[{"effect":"NoSchedule","key":"marketplace-userapp","value":"true"}]}}}}' -n kube-system


 
# Create a namespace with the name entered by the user
kubectl create namespace $org_name




# Apply the Helm chart using the inputs provided by the user
helm template . \
--set s3microservices.AWS_ACCESS_KEY_ID=$aws_key \
--set s3microservices.AWS_SECRET_ACCESS_KEY=$aws_secret_key \
--set urls.BASE_URL=http://cloudifytests-session-be.$org_name.svc.cluster.local:5000/ \
--set s3microservices.S3_BUCKET=$s3_bucket \
--set s3microservices.AWS_DEFAULT_REGION=$aws_region \
--set sessionbe.serviceAccountName=$org_name --set nginxhpa.metadata.namespace=$org_name \
--set be.ORG_NAME=$org_name \
--set sessionbe.image.repository="$be" \
--set sessionUi.image.repository="$Ui" \
--set smcreate.image.repository="$create" \
--set smdelete.image.repository="$delete" \
--set sessionmanager.AWS_ECR_IMAGE=public.ecr.aws/r2h8i7a4 \
--set smlogsvalues.ORG_NAME=$org_name \
--set behpa.metadata.namespace=$org_name --set sessionManagaerhpa.metadata.namespace=$org_name \
--set role.metadata.namespace=$org_name --set roleBinding.metadata.namespace=$org_name \
--set smcreatehpa.metadata.namespace=$org_name --set smdeletehpa.metadata.namespace=$org_name \
--set serviceaccount.metadata.namespace=$org_name \
--set SETUP_METHOD="aws" \
--set roleBinding.subjects.namespace=$org_name | kubectl create --namespace $org_name -f -

#Roll back Code

echo -e "\nWait for sometime.\n"
sleep 120
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
  hostname=$(kubectl get ing -n $org_name cloudifytests -o 'go-template={{range .status.loadBalancer.ingress}}{{.hostname}}{{end}}')
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
echo "Wait for 1 minutes and use this hostname to access the application"
fi
else
#echo -e "$var"
echo -e "\nSomething went wrong Wait for sometime for the  namespace to be deleted\n"
kubectl delete ns $org_name
echo -e "\nNamespace $org_name deleted\nTry to run the command again\n"
fi
