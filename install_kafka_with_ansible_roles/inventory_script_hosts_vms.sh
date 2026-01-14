#!/usr/bin/env bash
# filepath: install_kafka_with_ansible_roles/inventory_script_hosts_vms.sh

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <resource-group> <admin-username>" >&2
    exit 1
fi

resource_group="$1"
admin_user="$2"

# Get all VMs with names starting with "kafka-prod-broker-"
vm_list=$(az vm list -g "$resource_group" --query "[?starts_with(name, 'kafka-prod-broker-')]" -o json)

# Extract private IPs sorted by VM name
private_ips=$(echo "$vm_list" | jq -r 'sort_by(.name) | .[].privateIps' | tr ',' '\n')

echo "[kafka]"
index=1
while IFS= read -r ip; do
    [ -z "$ip" ] && continue
    # Format: hostname ansible_host=IP private_ip=IP kafka_node_id=INDEX
    printf 'kafka-broker-%02d ansible_host=%s private_ip=%s kafka_node_id=%d\n' "$index" "$ip" "$ip" "$index"
    index=$((index + 1))
done <<< "$private_ips"

echo "[all:vars]"
echo "ansible_user=$admin_user"
echo "ansible_ssh_private_key_file=~/.ssh/id_rsa"
echo "ansible_python_interpreter=/usr/bin/python3"

# Generate monitoring inventory
mkdir -p monitoring
cat > monitoring/generated_inventory.ini <<'EOF'
[management_node]
mgmt-kafka-monitor ansible_connection=local ansible_user=azureadmin

[kafka_broker]
EOF

index=1
while IFS= read -r ip; do
    [ -z "$ip" ] && continue
    printf 'kafka-broker-%02d ansible_host=%s ansible_user=%s\n' "$index" "$ip" "$admin_user" >> monitoring/generated_inventory.ini
    index=$((index + 1))
done <<< "$private_ips"