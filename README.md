# Kafka Deployment on Azure Using Ansible roles and Terraform

This repository contains the necessary configuration to deploy Apache Kafka on Azure using Ansible and Terraform. You can follow these instructions to deploy Kafka on Azure either using an Ubuntu machine or Windows Subsystem for Linux (WSL).

The project offers two deployment methods that differ in their approach to networking and public IP usage.

## Prerequisites

Ensure the following tools are installed on your machine:

- **Azure CLI**
- **Terraform**
- **jq**
- **Ansible** (only required for Method 1)

## Azure Authentication and Configuration

1. Login to your Azure account via the CLI:

    ```bash
    az login
    ```
This will prompt you to authenticate through a browser.

2. Set subscription and tenant IDs

The subscription and tenant IDs are required to execute Terraform for Azure. There are two methods to configure them:
* Set environment variables, as shown below:
    ```bash
    export ARM_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    export ARM_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    ```

* Set them directly in the provider.tf file, as shown below:
    ```hcl
    provider "azurerm" {
      features = {}
      subscription_id = "<YOUR_SUBSCRIPTION_ID>"
      tenant_id       = "<YOUR_TENANT_ID>"
    }
    ```

## Deployment Methods

### Method 1: Direct Deployment with Public IPs

This method provisions VMs with public IPs and installs Kafka directly from your local machine.

**Advantages:**
- Simple and straightforward
- Direct access to all VMs

**Disadvantages:**
- Requires multiple public IPs (one per VM)
- Higher security exposure

#### Steps:

1. Initialize Terraform
Run the following command to initialize Terraform and download the necessary provider plugins:

    ```bash
    cd kafka_setup_terraform
    terraform init
    ```

2. Apply Terraform Configuration
Once the initialization is complete, apply the configuration to provision resources on Azure:

    ```bash
    terraform apply
    ```

This will create the necessary resources for your Kafka deployment on Azure. Review the plan and confirm by typing yes.

#### Automated Kafka Deployment

After running terraform apply, the infrastructure will be provisioned automatically, and the Kafka installation and configuration will begin immediately. The entire process is automated via Terraform, which triggers Ansible dynamically.

Here's how it works:

* Terraform provisions the infrastructure (e.g., virtual machines, networking, etc.).
* Once the provisioning is complete, the inventory_script_hosts.sh script is executed through terraform's triggers. This script detects the public IPs of the created instances and automatically updates the hosts file.
* Ansible is invoked from within Terraform to automatically configure and install Kafka on the newly provisioned VMs.

This eliminates the need to manually trigger any Ansible playbooks and ensures a seamless, automated deployment process.

**Note:** The number of virtual machines is configured in the vmss.tf file (2 instances by default). This can be modified, and the deployment will still succeed regardless of the number of instances configured, as long as the allowed maximum number of public IP addresses is not exceeded.

---

### Method 2: Control Node Deployment with Private IPs (Recommended)

This method creates a control node VM on Azure that provisions and manages Kafka VMs using private IPs within the same VNet. This minimizes public IP usage to just one (for the control node).

**Advantages:**
- Uses only one public IP (for the control node)
- Enhanced security with private networking
- All Kafka VMs communicate via private IPs
- Remote management of infrastructure without SSH access to control node

**Disadvantages:**
- Slightly more complex setup
- Requires additional configuration file (secret.tfvars)

#### Prerequisites:

Create a `secret.tfvars` file in the `setup_control_node_terraform` directory with the following variables:

```hcl
github_token        = "your_github_personal_access_token"
ARM_SUBSCRIPTION_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
tf_cmd_type         = "apply"  # or "destroy" to tear down remote infrastructure
```

**Variable descriptions:**
- `github_token`: GitHub personal access token that will be stored in Azure Key Vault. The control node uses this to clone your repository containing the Kafka deployment configuration.
- `ARM_SUBSCRIPTION_ID`: Your Azure subscription ID.
- `tf_cmd_type`: Terraform command type to execute on the control node (`apply` to provision, `destroy` to tear down).

#### Steps:

1. Initialize Terraform for the control node:

    ```bash
    cd setup_control_node_terraform
    terraform init
    ```

2. Provision the control node:

    ```bash
    terraform apply -var-file='secret.tfvars'
    ```

This will:
* Create a control node VM on Azure with a public IP
* Store the GitHub token in Azure Key Vault
* Install Terraform and Ansible on the control node
* Generate SSH certificates
* Clone your repository using the GitHub token
* Execute the `private_vmss_init.sh` script automatically via Terraform provisioner

3. Automated Infrastructure Provisioning:

Once the control node is ready, it automatically:
* Uses the `kafka_setup_terraform_private_vmss` folder to provision Kafka VMs with private IPs in the same VNet
* Configures dynamic inventory for Ansible
* Launches Kafka installation automatically through a provisioner
* All VMs communicate via private IPs within the VNet

The entire process is fully automated after the initial `terraform apply` command.

#### Destroying Infrastructure:

To destroy the infrastructure provisioned by the control node **without** SSH access:

1. Update `secret.tfvars` and set:
    ```hcl
    tf_cmd_type = "destroy"
    ```

2. Run:
    ```bash
    terraform apply -var-file='secret.tfvars'
    ```

This will instruct the control node to destroy the remote Kafka infrastructure.

3. To destroy the control node itself and all associated resources:
    ```bash
    terraform destroy
    ```

**Important:** Always destroy the remote infrastructure first (step 1-2) before destroying the control node (step 3).

---

## Architecture Changes

This deployment uses **individual Virtual Machines** instead of Virtual Machine Scale Sets (VMSS) for the Kafka brokers. This provides:

- **Better control** over individual broker configurations
- **Easier debugging** with direct VM access
- **More flexible scaling** - add or remove specific VMs
- **Simpler disk management** with direct disk attachments

### Scaling the Cluster

To change the number of Kafka brokers, modify the `kafka_instance_count` variable:

```hcl
# In secret.tfvars or variables.tf
kafka_instance_count = 5  # Can be 3, 5, 7, 9, etc. (odd numbers recommended for quorum)
```

## Conclusion

After executing terraform apply (using either method), Kafka will be fully deployed and configured on your Azure environment. You can now interact with your Kafka instances.

**Choosing a Method:**
- Use **Method 1** for quick testing or when public IPs are not a concern
- Use **Method 2** for production environments or when minimizing public IP usage and enhancing security is important
