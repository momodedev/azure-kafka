#!/bin/bash
# Bootstrap script for Kafka installation on each VM

set -euo pipefail

# Log output
exec > /var/log/kafka-bootstrap.log 2>&1

echo "=== Starting Kafka Bootstrap ==="
echo "Hostname: $(hostname)"
echo "Date: $(date)"

# Update system
dnf update -y
dnf install -y git python3 python3-pip

# Install Ansible
pip3 install ansible

# Clone the repository
mkdir -p /opt
cd /opt
git clone https://github.com/momodedev/azure-kafka.git || true
cd azure-kafka

# Set Kafka broker ID based on VM hostname
KAFKA_BROKER_ID=$(hostname | grep -oP '(?<=-)\d+$')
echo "Kafka Broker ID: $KAFKA_BROKER_ID"

# Run Kafka installation Ansible role locally
cd install_kafka_with_ansible_roles
ansible-playbook -i localhost, -c local deploy_kafka_playbook.yaml -e "kafka_node_id=${KAFKA_BROKER_ID}"

echo "=== Kafka Bootstrap Complete ==="
