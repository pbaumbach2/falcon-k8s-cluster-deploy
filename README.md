# falcon-k8s-cluster-deploy

Bash script to deploy latest versions of Node Sensor daemonset or Container Sensor Injector, Kubernetes Protection Agent(KPA), Kubernetes Admission Controller(KAC), and Image at Runtime Scanner (IAR) pulling all images from the CrowdStrike Registry.

## Purpose:

To facilitate quick deployment of recommended CWP resources for testing.

For other deployment methods including hosting sensor in private registry, Terraform, etc., see CrowdStrike documentation and CrowdStrike GitHub.

## Prerequisite:

- Script requires the following commands to be installed:
-  `curl`
-  `helm`
- CrowdStrike API Client created with `Falcon Images Download (read)`, `Sensor Download (read)`, `Kubernetes Protection Agent (write)`, and `Kubernetes Protection (read/write)` scope assigned.
- Cluster name

## Usage:

```

usage: ./falcon-k8s-cluster-deploy.sh

Required Flags:
    -u, --client-id <FALCON_CLIENT_ID>             Falcon API OAUTH Client ID
    -s, --client-secret <FALCON_CLIENT_SECRET>     Falcon API OAUTH Client Secret
    -r, --region <FALCON_REGION>                   Falcon Cloud Region [us-1, us-2, eu-1, gov-1, or gov-2]
    -c, --cluster <K8S_CLUSTER_NAME>               Cluster name
Optional Flags:
    --sidecar                        Deploy container sensor as sidecar. Existing pods must be restarted to install sidecar sensors.
    --ebpf                           Deploy Falcon sensor in eBPF (user) mode. (Used for Google COS, Flatcar, CoreOS, etc)
    --azure                          Enables IAR scanning for ACR sourced images on Azure using default Azure config JSON file path   
    --skip-sensor                    Skip deployment of Falcon sensor
    --skip-kpa                       Skip deployment of KPA (Kubernetes Protection Agent) 
    --skip-kac                       Skip deployment of KAC (Kubernetes Admission Control)
    --skip-iar                       Skip deployment of IAR (Image at Runtime Scanning)
    --uninstall                      Uninstalls all components

Help Options:
    -h, --help display this help message"

```

  

Execute the script with the required and relevant input arguments. 
Script references falcon-container-sensor-pull.sh from https://github.com/CrowdStrike/falcon-scripts/tree/main/bash/containers/falcon-container-sensor-pull 

  The node sensor will deploy as a daemonset and automatically protect the host and all containers on the host.

  The sidecar sensor will deploy sensor injector pods. The injector will deploy the sidecar sensor into all newly started pods. Pre-existing workloads must be redeployed to be protected. The pull secret will be deployed into all namespaces at the time of helm chart deployment.

  #### Example to deploy node sensor as daemonset, KPA, KAC, and IAR:

```

./falcon-k8s-cluster-deploy.sh \
--client-id <ABCDEFG123456> \
--client-secret <ABCDEFG123456> \
--cluster <myclustername>

```

  

#### Example to deploy sidecar sensor. KPA, KAC, and IAR:

  

```

./falcon-k8s-cluster-deploy.sh \
--client-id <ABCDEFG123456> \
--client-secret <ABCDEFG123456> \
--cluster <myclustername> \
--sidecar

```

  

### Full list of variables available

> **Note**: **Settings can be passed to the script via CLI flags or environment variables:**

| Flags                                          | Environment Variables   | Default                    | Description                                                                              |
|:-----------------------------------------------|-------------------------|----------------------------|------------------------------------------------------------------------------------------|
| `-u`, `--client-id <FALCON_CLIENT_ID>` | `$FALCON_CLIENT_ID` | `None` (Required) | CrowdStrike API Client ID 
| `-s`, `--client-secret <FALCON_CLIENT_SECRET>` | `$FALCON_CLIENT_SECRET` | `None` (Required) | CrowdStrike API Client Secret |
| `-r`, `--region <FALCON_CLOUD>` | `$FALCON_CLOUD` | `None` (Required) | CrowdStrike Region | |
| `-c` | `K8S_CLUSTER_NAME` | `None` (Required) | Name of Kubernetes Cluster
| `--sidecar` | N/A | `false` | Deploys sidecar sensor injector as daemonset
| `--ebpf` | N/A | `false` | Deploys node sensor in user / eBPF mode instead of kernel mode. Not compatible with sidecar sensor.
| `--azure` | N/A | `false` | Enables IAR scanning for ACR sourced images on Azure using default Azure config JSON file path  . 
| `--autopilot` | N/A | `false` | For deployments onto GKE autopilot. Defaults to eBPF / User mode.
| `--skip-sensor` | N/A | `false` | Skips deployment of Falcon Sensor
| `--skip-kpa` | N/A | `false` | Skips deployment of Kubernetes Protection Agent (KPA)
| `--skip-kac` | N/A | `false` | Skips deployment of Kubernetes Admission Controller (KAC)
| `--skip-iar` | N/A | `false` | Skips deployment of Image at Runtime Scanner (IAR)
| `--uninstall` | N/A | `false` | Uninstalls all components
| `-h`, `--help` | N/A | `None` | Display help message

  

### Uninstall Helm Chart

To uninstall, run the following command:

```
./falcon-k8s-cluster-deploy.sh --uninstall
``` 
