# MySQL Infrastructure on Azure (Terraform + Ansible)

Quick start guide to deploy the MySQL Cluster infrastructure.

## Prerequisites

1.  **Azure CLI**: [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
2.  **Terraform**: [Install Terraform](https://developer.hashicorp.com/terraform/install)
3.  **Network Access**: Since this deployment is **Private Link / Internal VNet only**, you must run the deployment from a machine that has access to the Azure Subscription, and you must have a way to access the Private IPs (VPN, ExpressRoute, or Jumpbox) to manage the servers.

## Quick Start

### 1. Login to Azure
Open your terminal (PowerShell or Bash) and log in:
```bash
az login
```
If you have multiple subscriptions, set the correct one:
```bash
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Configure Settings
Open `terraform.tfvars` and **you must update the following values**:
*   `subscription_id`: Change `"CHANGE_ME_..."` to your real Subscription ID.
*   `ssh_public_key`: Change `"ssh-ed25519 CHANGE_ME..."` to your own local SSH public key (e.g. content of `~/.ssh/id_rsa.pub`).

### 3. Deploy Infrastructure
Initialize and apply the Terraform configuration:

```bash
terraform init
terraform apply -auto-approve
```

Wait for the process to complete (approx. 5-10 minutes).

### 4. Access the Environment

The Ansible Controller is deployed **without a Public IP** for security.
You must access it via the VNet (e.g., via VPN, ExpressRoute, or a Jumpbox).

Private IP: `172.16.1.5` (default dynamic, check Azure Portal)



### 5. Deployment Verification
Inside the Ansible Controller, you can verify connectivity to the Database nodes:

```bash
# Verify connectivity
ansible -i inventory.ini all -m ping
```

### 6. Install MySQL (Run Ansible)

The Terraform deployment only sets up the **Infrastructure**. You must now copy the Ansible playbooks to the controller and run them to install the software.

**Option A: Upload from Local (SCP)**
From your local machine (where `ansible-mysql` folder is located):
```bash
# Upload playbook folder to Controller
scp -r ../ansible-mysql azureuser@172.16.1.5:/home/azureuser/
```

**Option B: Clone from Git**
If you have hosted the `ansible-mysql` code in a Git repo, you can clone it directly on the Controller:
```bash
ssh azureuser@172.16.1.5
git clone https://your-repo-url.git ansible-mysql
```

**Run the Playbook:**
Once the files are on the Controller (SSH in):
```bash
cd ansible-mysql
# 1. Update secrets.yml with your desired passwords
cp secrets.yml.example secrets.yml
vi secrets.yml

# 2. Run the main playbook
ansible-playbook -i ../mysql_inventory.ini 00_main_deploy.yml
```

---
**Note:** A secure SSH key pair for Ansible-to-Database communication is automatically generated and configured during deployment. You do not need to manually manage internal keys.
