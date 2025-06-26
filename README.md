# 🌍 Multi-Region Azure Kubernetes Service (AKS) with Hybrid Cloud

This repository contains the **Infrastructure as Code (IaC)** for deploying a **robust, highly available, secure**, and **observable** cloud infrastructure on **Microsoft Azure**.

The objective is to build a resilient platform for hosting containerized applications (microservices) **across multiple geographical regions**, with **on-premises integration** and **centralized observability** using **Terraform**.

---

## 🏗️ Architecture Overview

At the heart of this setup is a **multi-region AKS deployment**, enabling global application availability and disaster recovery.

- **🌐 Global Traffic Management**  
  Azure **Traffic Manager** routes users to the most performant AKS cluster using DNS-based, performance-aware routing.

- **📍 Regional AKS Deployments**  
  Two AKS clusters are deployed in **Central US** and **West US 3**, each in separate **VNets** with **public and private subnets**.

- **🔁 Cross-Region Connectivity**  
  **VNet peering** enables secure, low-latency communication between regions.

- **🏢 Hybrid Cloud Integration**  
  A simulated on-premises network is connected via **Site-to-Site VPN**, ensuring secure hybrid access.

- **🔐 Centralized Services**  
  - **Azure Container Registry (ACR)** – for container image storage.  
  - **Azure Key Vault** – for secrets management.  
  - **Azure Monitor & Log Analytics** – for logs, metrics, and diagnostics.

---

## 🌟 Key Features & Benefits

- **✅ High Availability & Disaster Recovery**  
  Multi-region AKS with Traffic Manager guarantees uptime and geo-redundancy.

- **🛡️ Enhanced Security**  
  Includes public/private subnet isolation, NSGs, Key Vault, Managed Identities, and encrypted VPN traffic.

- **⚡ Optimal Performance**  
  Traffic Manager routes users to the nearest, healthiest region to reduce latency.

- **🌐 Hybrid Connectivity**  
  Secure access between Azure and on-premises systems.

- **🤖 Operational Efficiency**  
  Fully automated IaC with **Terraform**.

- **📊 Comprehensive Observability**  
  Logs and metrics are centralized in **Azure Monitor**, enhanced by **New Relic** APM.

---

## 🧰 Technologies Used

- **Azure Kubernetes Service (AKS)** – Container orchestration  
- **Azure Virtual Network (VNet)** – Network backbone  
- **Azure Container Registry (ACR)** – Private Docker registry  
- **Azure Traffic Manager** – Global traffic routing  
- **Azure Key Vault** – Secrets management  
- **Azure VPN Gateway** – Site-to-Site hybrid VPN  
- **Azure Monitor & Log Analytics** – Observability  
- **Terraform** – Infrastructure as Code  
- **Python** – Sample microservice language  
- **Coverage.py** – Code coverage analysis  
- **Azure DevOps Pipelines** – CI/CD workflows  
- **SonarQube / SonarCloud** – Code quality and security scanning  
- **New Relic** – APM, tracing, and monitoring

---

## 📁 Project Structure

```bash
.
├── InfrastructureTerraform/      # Terraform configuration for Azure resources
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── k8s-specifications/           # Kubernetes manifests
│   ├── microservices/            #   - vote, result, worker, backend apps
│   └── services/                 #   - Kubernetes Services
├── vote/                         # Vote microservice code
├── result/                       # Result microservice code
├── worker/                       # Worker microservice code
├── seed-data/                    # Backend microservice code
└── AzurePipelines/               # Azure DevOps pipeline definitions

## ⚙️ Implement CI/CD Pipelines with Azure DevOps

This repository includes sample `azure-pipelines.yml` definitions for setting up **Continuous Integration (CI)** and **Continuous Delivery (CD)** using **Azure DevOps**.

### 🧪 Individual CI Pipelines

Each microservice (e.g., **vote**, **result**, **worker**, **backend**) should have a dedicated CI pipeline that is triggered on every code push.

These pipelines will perform the following steps:

1. **Build the application code**
2. **Run unit tests**
   - Use `coverage.py` (for Python microservices) to measure test coverage
3. **Static code analysis**
   - Integrate with **SonarQube** or **SonarCloud**
   - Enforce **code quality** and **security gates**
4. **Build Docker images**
   - Use the Dockerfile from each microservice directory
5. **Push Docker images to Azure Container Registry (ACR)**
6. **Publish artifacts**
   - Store **test results**, **logs**, and **coverage reports**

💡 Example CI structure in YAML:

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: ubuntu-latest

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.x'

  - script: |
      pip install -r requirements.txt
      coverage run -m unittest discover
      coverage report
    displayName: 'Run Tests'

  - task: SonarCloudPrepare@1
    # SonarCloud setup here...

  - task: Docker@2
    inputs:
      containerRegistry: 'YourACRServiceConnection'
      repository: 'your-app'
      command: 'buildAndPush'
      Dockerfile: '**/Dockerfile'
