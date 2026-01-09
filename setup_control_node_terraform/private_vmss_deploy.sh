#!/bin/bash


source ansible-venv/bin/activate
cd azure-kafka-deployment/kafka_setup_terraform_private_vmss
git pull
echo "ARM_SUBSCRIPTION_ID=\"$1\"" > sub_id.tfvars
echo "kafka_instance_count=3" >> sub_id.tfvars
terraform init
terraform $2 -var-file='sub_id.tfvars' -auto-approve
