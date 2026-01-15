#!/usr/bin/env bash
# filepath: install_kafka_with_ansible_roles/inventory_script_hosts_vms.sh

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <resource-group> <admin-username>" >&2
    exit 1
fi

resource_group="$1"
admin_user="$2"

# Get all VMs with names starting with "kafka-prod-broker-" sorted by name
vm_names=$(az vm list -g "$resource_group" --query "[?starts_with(name, 'kafka-prod-broker-')].name" -o tsv | sort)

# Extract private IPs for each VM
private_ips=()
for vm_name in $vm_names; do
    private_ip=$(az vm list-ip-addresses -g "$resource_group" -n "$vm_name" --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)
    if [[ -z "$private_ip" || "$private_ip" == "null" ]]; then
        echo "Warning: Could not get private IP for $vm_name" >&2
        continue
    fi
    private_ips+=("$private_ip")
done

echo "[kafka]"
index=1
for ip in "${private_ips[@]}"; do
    printf 'kafka-broker-%02d ansible_host=%s private_ip=%s kafka_node_id=%d\n' "$index" "$ip" "$ip" "$index"
    index=$((index + 1))
done

echo "[all:vars]"
echo "ansible_user=$admin_user"
echo "ansible_ssh_private_key_file=~/.ssh/id_rsa"
echo "ansible_python_interpreter=/usr/bin/python3"

# Generate monitoring inventory
mkdir -p monitoring
cat > monitoring/generated_inventory.ini <<'EOF'
[management_node]
localhost ansible_connection=local ansible_user=azureadmin

[kafka_broker]
EOF

index=1
for ip in "${private_ips[@]}"; do
    # IMPORTANT: Use just the IP, don't add port here - kafka_exporter role adds :9092
    printf 'kafka-broker-%02d ansible_host=%s ansible_user=%s\n' "$index" "$ip" "$admin_user" >> monitoring/generated_inventory.ini
    index=$((index + 1))
done