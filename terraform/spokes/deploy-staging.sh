#!/bin/bash
set -e

# Set AWS profile and region for staging
export AWS_PROFILE=eksstaging
export AWS_REGION=eu-west-2

# Variables
BUCKET_NAME="eks-fleet-terraform-state-staging"
REGION="eu-west-2"
VPC_NAME="eks-fleet-staging-workload-1"

echo "Using AWS Profile: $AWS_PROFILE"
echo "Region: $REGION"

# Create S3 bucket for terraform state if it doesn't exist
if ! aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
  echo "Creating S3 bucket for terraform state..."
  aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION
  
  # Enable versioning
  aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled
  
  # Enable encryption
  aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          }
        }
      ]
    }'
fi

# Check if VPC already exists
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query "Vpcs[0].VpcId" --output text)

if [ "$VPC_ID" == "None" ]; then
  echo "Creating new VPC: $VPC_NAME"
  
  # Create VPC
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
    --query Vpc.VpcId --output text)
  
  # Enable DNS hostnames
  aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames "{\"Value\":true}"
  
  # Create subnets - 2 private and 2 intra subnets across 2 AZs for cost efficiency
  echo "Creating private subnets..."
  PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.0.0/19 \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=private-${REGION}a}]" \
    --query Subnet.SubnetId --output text)
  
  PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.32.0/19 \
    --availability-zone ${REGION}b \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=private-${REGION}b}]" \
    --query Subnet.SubnetId --output text)
  
  echo "Creating intra subnets..."
  INTRA_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.64.0/19 \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=intra-${REGION}a}]" \
    --query Subnet.SubnetId --output text)
  
  INTRA_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.96.0/19 \
    --availability-zone ${REGION}b \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=intra-${REGION}b}]" \
    --query Subnet.SubnetId --output text)
  
  # Create a single public subnet for NAT Gateway
  echo "Creating public subnet..."
  PUBLIC_SUBNET=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.128.0/19 \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=public-${REGION}a}]" \
    --query Subnet.SubnetId --output text)
  
  # Create Internet Gateway
  echo "Creating Internet Gateway..."
  IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$VPC_NAME-igw}]" \
    --query InternetGateway.InternetGatewayId --output text)
  
  # Attach Internet Gateway to VPC
  aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID
  
  # Create NAT Gateway (single NAT Gateway for cost efficiency)
  echo "Creating NAT Gateway..."
  EIP_ALLOC=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$VPC_NAME-nat-eip}]" \
    --query AllocationId --output text)
  
  NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET \
    --allocation-id $EIP_ALLOC \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$VPC_NAME-nat}]" \
    --query NatGateway.NatGatewayId --output text)
  
  echo "Waiting for NAT Gateway to become available..."
  aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID
  
  # Create route tables
  echo "Creating route tables..."
  # Public route table
  PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-public-rt}]" \
    --query RouteTable.RouteTableId --output text)
  
  # Add route to Internet Gateway
  aws ec2 create-route \
    --route-table-id $PUBLIC_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID
  
  # Associate public subnet with public route table
  aws ec2 associate-route-table \
    --route-table-id $PUBLIC_RT \
    --subnet-id $PUBLIC_SUBNET
  
  # Private route table
  PRIVATE_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-private-rt}]" \
    --query RouteTable.RouteTableId --output text)
  
  # Add route to NAT Gateway
  aws ec2 create-route \
    --route-table-id $PRIVATE_RT \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID
  
  # Associate private subnets with private route table
  aws ec2 associate-route-table \
    --route-table-id $PRIVATE_RT \
    --subnet-id $PRIVATE_SUBNET_1
  
  aws ec2 associate-route-table \
    --route-table-id $PRIVATE_RT \
    --subnet-id $PRIVATE_SUBNET_2
  
  # Intra route table (no internet access)
  INTRA_RT=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-intra-rt}]" \
    --query RouteTable.RouteTableId --output text)
  
  # Associate intra subnets with intra route table
  aws ec2 associate-route-table \
    --route-table-id $INTRA_RT \
    --subnet-id $INTRA_SUBNET_1
  
  aws ec2 associate-route-table \
    --route-table-id $INTRA_RT \
    --subnet-id $INTRA_SUBNET_2
  
  # Add required tags for EKS
  echo "Adding required tags for EKS..."
  # Tag private subnets for internal load balancers
  aws ec2 create-tags \
    --resources $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2 \
    --tags Key=kubernetes.io/role/internal-elb,Value=1
  
  # Tag intra subnets for CNI
  aws ec2 create-tags \
    --resources $INTRA_SUBNET_1 $INTRA_SUBNET_2 \
    --tags Key=kubernetes.io/role/cni,Value=1
  
  echo "VPC created successfully: $VPC_ID"
else
  echo "Using existing VPC: $VPC_ID"
fi

# Initialize Terraform with the staging configuration
echo "Initializing Terraform..."
terraform init -reconfigure \
  -backend-config="bucket=$BUCKET_NAME" \
  -backend-config="key=eks-fleet/staging/terraform.tfstate" \
  -backend-config="region=$REGION" \
  -backend-config="encrypt=true"

# Apply Terraform with the staging tfvars
echo "Applying Terraform configuration..."
terraform apply -var-file=terraform.tfvars.staging

echo "Deployment complete!"
