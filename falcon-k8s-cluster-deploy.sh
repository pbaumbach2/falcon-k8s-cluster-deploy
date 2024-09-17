#!/bin/bash
: <<'#DESCRIPTION#'
File: falcon-k8s-deploy.sh
Description: Bash script for x86 architecture to deploy Falcon Node Sensor as daemonset, KPA, KAC, IAR scanning in watcher mode
Requirements: helm, curl 
#DESCRIPTION#

set -e

usage()
{
    echo "usage: $0

Required Flags:
    -u, --client-id <FALCON_CLIENT_ID>             Falcon API OAUTH Client ID
    -s, --client-secret <FALCON_CLIENT_SECRET>     Falcon API OAUTH Client Secret
    -r, --region <FALCON_REGION>                   Falcon Cloud Region [us-1, us-2, eu-1, gov-1, or gov-2]
    -c, --cluster <K8S_CLUSTER_NAME>               Cluster name
Optional Flags:
    --sidecar                        Deploy container sensor as sidecar. Existing pods must be restarted to install sidecar sensors.
    --azure                          Enables IAR scanning for ACR sourced images on Azure using default Azure config JSON file path   
    --autopilot                      For deployments onto GKE autopilot. Defaults to eBPF / User mode
    --skip-sensor                    Skip deployment of Falcon sensor
    --skip-kpa                       Skip deployment of KPA (Kubernetes Protection Agent) 
    --skip-kac                       Skip deployment of KAC (Kubernetes Admission Control)
    --skip-iar                       Skip deployment of IAR (Image at Runtime Scanning)
    --uninstall                      Uninstalls all components
    --tags <TAG1,TAG2>               Tag the Falcon sensor. Multiple tags must formatted with \, separators. e.g. --tags "exampletag1\,exampletag2"


Help Options:
    -h, --help display this help message"
    exit 2
}


die() {
    echo "Fatal error: $*" >&2
    exit 1
}

#Set Default Values
BACKEND=kernel
SKIPKPA=false
SKIPSENSOR=false
SKIPKAC=false
SKIPIAR=false
AZURE=false
UNINSTALL=false
AUTOPILOT=false
SIDECAR=false
#downloads sensor pull script to use within script
sensorpullscript=$(curl -s https://raw.githubusercontent.com/CrowdStrike/falcon-scripts/main/bash/containers/falcon-container-sensor-pull/falcon-container-sensor-pull.sh)


#Ensure User Mode Enabled if Autopilot
if [ "$AUTOPILOT" = true ]; then
    BACKEND=bpf
    echo "GKE Autopilot enabled. Deploying node sensor backend to User Mode (eBPF)"
fi


#Parse options
while [ $# != 0 ]; do
case "$1" in
    -u|--client-id)
    if [ -n "${2:-}" ] ; then
        export FALCON_CLIENT_ID="${2}"
        shift
    fi
    ;;
    -s|--client-secret)
    if [ -n "${2:-}" ]; then
        export FALCON_CLIENT_SECRET="${2}"
        shift
    fi
    ;;
    -r|--region)
    if [ -n "${2:-}" ]; then
        FALCON_CLOUD="${2}"
        shift
    fi
    ;;
    -c|--cluster)
    if [ -n "${2}" ]; then
        K8S_CLUSTER_NAME="${2}"
        shift
    fi
    ;;
   -t|--tags)
    if [ -n "${2}" ]; then
        SENSOR_TAGS="${2}"
        shift
    fi
    ;;
    --ebpf)
    if [ -n "${1}" ]; then
        BACKEND="bpf"      
    fi
    ;;
    --skip-kpa)
    if [ -n "${1}" ]; then
        SKIPKPA=true
    fi
    ;;
    --skip-sensor)
    if [ -n "${1}" ]; then
        SKIPSENSOR=true
    fi
    ;;
    --sidecar)
    if [ -n "${1}" ]; then
        SIDECAR=true
    fi
    ;;
    --skip-kac)
    if [ -n "${1}" ]; then
        SKIPKAC=true
    fi
    ;;
    --skip-iar)
    if [ -n "${1}" ]; then
        SKIPIAR=true
    fi
    ;;
    --azure)
    if [ -n "${1}" ]; then
        AZURE=true
    fi
    ;;
    --autopilot)
    if [ -n "${1}" ]; then
        AUTOPILOT=true
    fi
    ;;
    --uninstall)
    if [ -n "${1}" ]; then
        UNINSTALL=true
    fi
    ;;
    -h|--help)
    if [ -n "${1}" ]; then
        usage
    fi
    ;;
    --) # end argument parsing
    shift
    break
    ;;
    -*) # unsupported flags
    >&2 echo "ERROR: Unsupported flag: '${1}'"
    usage
    ;;
esac
shift
done

#Get the falcon sensor image details and pull token and Deploy Daemonset
function deploy_sensor {
    echo Deploying Falcon Sensor as Daemonset
    export FALCON_CID=$( bash <( echo "$sensorpullscript") -t falcon-sensor --get-cid )
    export FALCON_IMAGE_FULL_PATH=$( bash <(echo "$sensorpullscript") -t falcon-sensor --get-image-path )
    export FALCON_IMAGE_REPO=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 1 )
    export FALCON_IMAGE_TAG=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 2 )
    export FALCON_IMAGE_PULL_TOKEN=$( bash <(echo "$sensorpullscript") -t falcon-sensor --get-pull-token )
    bash  <(echo "$sensorpullscript") -t falcon-sensor --get-cid

    helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
    helm upgrade --install falcon-sensor crowdstrike/falcon-sensor -n falcon-system --create-namespace \
    --set falcon.cid="$FALCON_CID" \
    --set falcon.tags="$SENSOR_TAGS" \
    --set node.image.repository="$FALCON_IMAGE_REPO" \
    --set node.image.tag="$FALCON_IMAGE_TAG" \
    --set node.image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN" \
    --set node.gke.autopilot="$AUTOPILOT"
}

function deploy_container_sensor {
    export FALCON_CID=$( bash <(echo "$sensorpullscript") -t falcon-container --get-cid )
    export FALCON_IMAGE_FULL_PATH=$( bash <(echo "$sensorpullscript") -t falcon-container --get-image-path )
    export FALCON_IMAGE_REPO=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 1 )
    export FALCON_IMAGE_TAG=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 2 )
    export FALCON_IMAGE_PULL_TOKEN=$( bash <(echo "$sensorpullscript") -t falcon-container --get-pull-token )

    helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
    helm upgrade --install falcon-sensor crowdstrike/falcon-sensor -n falcon-system --create-namespace \
    --set node.enabled=false \
    --set container.enabled=true \
    --set falcon.cid="$FALCON_CID" \
    --set falcon.tags="$SENSOR_TAGS" \
    --set container.image.repository="$FALCON_IMAGE_REPO" \
    --set container.image.tag="$FALCON_IMAGE_TAG" \
    --set container.image.pullSecrets.enable=true \
    --set container.image.pullSecrets.allNamespaces=true \
    --set container.image.pullSecrets.registryConfigJSON=$FALCON_IMAGE_PULL_TOKEN \
    --set container.image.pullSecrets.namespaces=""
}

#Install Falcon Kubernetes Admission controller (KAC)
function deploy_kac {
    export FALCON_CID=$( bash <(echo "$sensorpullscript") -t falcon-kac --get-cid )
    export FALCON_KAC_IMAGE_FULL_PATH=$( bash <(echo "$sensorpullscript") -t falcon-kac --get-image-path )
    export FALCON_KAC_IMAGE_REPO=$( echo $FALCON_KAC_IMAGE_FULL_PATH | cut -d':' -f 1 )
    export FALCON_KAC_IMAGE_TAG=$( echo $FALCON_KAC_IMAGE_FULL_PATH | cut -d':' -f 2 )
    export FALCON_IMAGE_PULL_TOKEN=$( bash <(echo "$sensorpullscript") -t falcon-kac --get-pull-token )

    helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
    helm upgrade --install falcon-kac crowdstrike/falcon-kac -n falcon-kac --create-namespace \
        --set falcon.cid="$FALCON_CID" \
        --set falcon.tags="$SENSOR_TAGS" \
        --set image.repository="$FALCON_KAC_IMAGE_REPO" \
        --set image.tag="$FALCON_KAC_IMAGE_TAG" \
        --set image.registryConfigJSON="$FALCON_IMAGE_PULL_TOKEN"
}

#Install Falcon Kubernetes Protection (KPA)
#KPA uses difference CID Format from other components, (all lower without checksum)
function deploy_kpa {
    export FALCON_CID_KPA=$( bash <(echo "$sensorpullscript") -t kpagent --get-cid )
    export FALCON_KPA_IMAGE_FULL_PATH=$( bash <(echo "$sensorpullscript") -t kpagent --get-image-path )
    export FALCON_KPA_IMAGE_REPO=$( echo $FALCON_KPA_IMAGE_FULL_PATH | cut -d':' -f 1 )
    export FALCON_KPA_IMAGE_TAG=$( echo $FALCON_KPA_IMAGE_FULL_PATH | cut -d':' -f 2 )
    export FALCON_IMAGE_PULL_TOKEN=$( bash <(echo "$sensorpullscript") -t kpagent --get-pull-token )
    helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm --force-update
    helm upgrade --install kpagent crowdstrike/cs-k8s-protection-agent -n falcon-kubernetes-protection --create-namespace \
        --set image.registryConfigJSON=$FALCON_IMAGE_PULL_TOKEN \
        --set image.repository=$FALCON_KPA_IMAGE_REPO \
        --set image.tag=$FALCON_KPA_IMAGE_TAG \
        --set crowdstrikeConfig.cid=$FALCON_CID_KPA \
        --set crowdstrikeConfig.clientID=$FALCON_CLIENT_ID \
        --set crowdstrikeConfig.clientSecret=$FALCON_CLIENT_SECRET \
        --set crowdstrikeConfig.clusterName=$K8S_CLUSTER_NAME \
        --set crowdstrikeConfig.env=$FALCON_CLOUD
}

 #Deploying Image Assessment at Runtime (IAR)
function deploy_iar {
    export FALCON_CID=$( bash <(echo "$sensorpullscript") -t falcon-imageanalyzer --get-cid )
    export FALCON_IMAGE_FULL_PATH=$( bash <(echo "$sensorpullscript") -t falcon-imageanalyzer --get-image-path )
    export FALCON_IMAGE_REPO=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 1 )
    export FALCON_IMAGE_TAG=$( echo $FALCON_IMAGE_FULL_PATH | cut -d':' -f 2 )
    export FALCON_IMAGE_PULL_TOKEN=$( bash <(echo "$sensorpullscript") -t falcon-imageanalyzer --get-pull-token )

    helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
    helm repo update
    helm upgrade --install iar crowdstrike/falcon-image-analyzer \
    -n falcon-image-analyzer --create-namespace \
    --set deployment.enabled=true \
    --set crowdstrikeConfig.cid="$FALCON_CID" \
    --set crowdstrikeConfig.clusterName="$K8S_CLUSTER_NAME" \
    --set crowdstrikeConfig.clientID=$FALCON_CLIENT_ID \
    --set crowdstrikeConfig.clientSecret=$FALCON_CLIENT_SECRET \
    --set crowdstrikeConfig.agentRegion=$FALCON_CLOUD \
    --set image.registryConfigJSON=$FALCON_IMAGE_PULL_TOKEN \
    --set image.repository="$FALCON_IMAGE_REPO" \
    --set image.tag="$FALCON_IMAGE_TAG" \
    --set azure.enabled=$AZURE
}
function uninstall {
    echo "Uninstalling Falcon Cloud Security for Containers Components"
    if [ -n "$(eval "helm list --filter 'falcon-sensor' -n falcon-system | grep falcon-sensor")" ]; then
        helm uninstall falcon-sensor -n falcon-system 
    fi
    if [ -n "$(eval "helm list --filter 'falcon-kac' -n falcon-kac | grep falcon-kac")" ]; then
        helm uninstall falcon-kac -n falcon-kac
    fi
    if [ -n "$(eval "helm list --filter 'kpagent' -n falcon-kubernetes-protection | grep kpagent")" ]; then
        helm uninstall kpagent -n falcon-kubernetes-protection
    fi
    if [ -n "$(eval "helm list --filter 'iar' -n falcon-image-analyzer | grep iar")" ]; then
        helm uninstall iar -n falcon-image-analyzer 
    fi
     
    if [ -n "$(eval "kubectl get ns | grep falcon-system")" ]; then
        kubectl delete ns falcon-system 
    fi
    if [ -n "$(eval "kubectl get ns | grep falcon-kac")" ]; then
        kubectl delete ns falcon-kac 
    fi
    if [ -n "$(eval "kubectl get ns | grep falcon-kubernetes-protection")" ]; then
        kubectl delete ns falcon-kubernetes-protection  
    fi
    if [ -n "$(eval "kubectl get ns | grep falcon-image-analyzer")" ]; then
        kubectl delete ns falcon-image-analyzer 
    fi
    # kubectl delete ns falcon-system --ignore-not-found
    # kubectl delete ns falcon-kac --ignore-not-found
    # kubectl delete ns falcon-kubernetes-protection --ignore-not-found
    # kubectl delete ns falcon-image-analyzer --ignore-not-found
}



if [ "$UNINSTALL" = true ]; then
    uninstall
else 

    if [ "$SKIPSENSOR" = false ] && [ "$SIDECAR" = false ]; then
        deploy_sensor
    fi

    if [ "$SKIPSENSOR" = false ] && [ "$SIDECAR" = true ]; then
        deploy_container_sensor
    fi

    if [ "$SKIPKPA" = false ]; then
        deploy_kpa
    fi

    if [ "$SKIPKAC" = false ]; then
        deploy_kac
    fi

    if [ "$SKIPIAR" = false ]; then
        deploy_iar
    fi

    #Echo the deployment checks
    echo ""
    echo "To Confirm Successful Deployment, Run The Following Commands:"
    echo ""
    echo "kubectl get pods -n falcon-system"
    echo "kubectl get pods -n falcon-kac"
    echo "kubectl get pods -n falcon-kubernetes-protection"
    echo "kubectl get pods -n falcon-image-analyzer"

fi 

