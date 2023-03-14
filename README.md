# Cloudifytests Infrastructure Installation Steps


This document provides the steps for installing the Cloudifytests product from AWS Marketplace.

## Prerequisites
1.  **Minimum requirements to run application on the cluster:-**

      *You need 4vCPU machine and 4gb ram*

     
                
### Quick Launch 
       
##### ***This repository comes with a quick launch script (quicklaunch.sh) that automates the process of deploying the application to a Kubernetes cluster.***




#### You will be prompted to enter the following information:

|    Field          |Description   |      Required / Optional    |
| :------------------:|:-----------------------:|:-----------------:|
| **Namespace Name**    |The name of the namespace to be created.|***Required***|
| **AWS Access Key**    |The Access Key for your AWS Account.|***Required***|
| **AWS Secret Key**    |The Secret Key for your AWS Account.|***Required***|
| **S3 Bucket name**    |The name of S3 bucket to use.|***Required***|
| **AWS Default Region**|The default region for your AWS Account.|***Required***|
| **AWS ECR Image**     |The name of the ECR image repository to use. |***Required***|
| **Cluster Name**      |The name of your Kubernetes Cluster.|***Required***|
      
All of the fields listed above must be provided by the user in order for the script to run correctly.

#### To launch Cloudify Tests using the Quick Launch method, run the following command:

      
        wget -qO quicklaunch.sh 'https://raw.githubusercontent.com/CloudifyLabs/Cloudifytests_charts/PL-2338/quicklaunch.sh' && bash quicklaunch.sh
       

Once the script has completed execution, the application will be deployed to your Kubernetes cluster in the specified namespace. You can use the LoadBalancer URL to access the application. 


   
