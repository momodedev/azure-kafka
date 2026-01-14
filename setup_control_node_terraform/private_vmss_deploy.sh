#!/bin/bash


source ansible-venv/bin/activate

REPO_DIR="azure-kafka"

if [ ! -d "$REPO_DIR/.git" ]; then
     echo "Repository not found; please rerun private_vmss_init.sh to clone it" >&2
     exit 1
 fi

echo "Fetching latest code from origin..."
git -C "$REPO_DIR" fetch origin --prune && git -C "$REPO_DIR" reset --hard origin/main

cd "$REPO_DIR/kafka_setup_terraform_private_vmss"
echo "ARM_SUBSCRIPTION_ID=\"$1\"" > sub_id.tfvars
echo "kafka_instance_count=${3:-3}" >> sub_id.tfvars
echo "kafka_data_disk_iops=${4:-3000}" >> sub_id.tfvars
echo "kafka_data_disk_throughput_mbps=${5:-125}" >> sub_id.tfvars
echo "kafka_vm_size=\"${6:-Standard_D4s_v5}\"" >> sub_id.tfvars
terraform init
terraform $2 -var-file='sub_id.tfvars' -auto-approve
