#!/bin/bash
#
# Copyright 2024 Tech Equity Cloud Services Ltd
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License. 
# 
#################################################################################
####  Explore Istio BookInfo Microservice Application in Google Cloud Shell #####
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=1 # $(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=1 # $(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e " Visit https://docs.techequity.cloud for terraform based rapid application deployment"
echo -e "          Developed by: Shiyghan Navti shiyghan.navti@techequity.cloud"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-istio-traffic > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-istio-traffic
export SCRIPTNAME=gcp-istio-traffic.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=gke-cluster
export ISTIO_VERSION=1.24.2
export ISTIO_RELEASE_VERSION=1.24
export GCP_REGION=us-central1
EOF
source $PROJDIR/.env
fi

export APPLICATION_NAMESPACE=bookinfo
export APPLICATION_NAME=bookinfo

# Display menu options
while :
do
clear
cat<<EOF
===========================================================================
Explore Traffic Management, Resiliency and Telemetry Features using Istio 
---------------------------------------------------------------------------
 (1) Install tools
 (2) Enable APIs
 (3) Create Kubernetes cluster
 (4) Install Istio
 (5) Configure namespace for automatic sidecar injection
 (6) Configure service and deployment
 (7) Configure gateway and virtualservice
 (8) Configure subsets
 (9) Explore Istio traffic management
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=$GCP_CLUSTER
export ISTIO_VERSION=$ISTIO_VERSION
export ISTIO_RELEASE_VERSION=$ISTIO_RELEASE_VERSION
export GCP_REGION=$GCP_REGION
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
        echo "*** Istio release version is $ISTIO_RELEASE_VERSION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=$GCP_CLUSTER
export ISTIO_VERSION=$ISTIO_VERSION
export ISTIO_RELEASE_VERSION=$ISTIO_RELEASE_VERSION
export GCP_REGION=$GCP_REGION
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
                echo "*** Istio release version is $ISTIO_RELEASE_VERSION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ curl -L https://github.com/istio/istio/releases/download/\${ISTIO_VERSION}/istio-\${ISTIO_VERSION}-linux-amd64.tar.gz | tar xz -C \$HOME # to download Istio" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ curl -L https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz | tar xz -C $HOME # to download Istio" | pv -qL 100
    curl -L https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz | tar xz -C $HOME 
    cd $HOME/istio-${ISTIO_VERSION} > /dev/null 2>&1 #Set project 
    export PATH=$HOME/istio-${ISTIO_VERSION}/bin:$PATH > /dev/null 2>&1 #Set project 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "$ rm -rf $HOME/istio-${ISTIO_VERSION} # to delete download" | pv -qL 100
    rm -rf $HOME/istio-${ISTIO_VERSION}
else
    export STEP="${STEP},1i"   
    echo
    echo "1. Download Istio" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},2i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$GCP_CLUSTER --region \$GCP_REGION --machine-type n1-standard-2 --num-nodes 2 --disk-size 50 --labels location=\$GCP_REGION --spot --gateway-api=standard # to create container cluster" | pv -qL 100
    echo      
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --region \$GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --region $GCP_REGION --machine-type n1-standard-2 --num-nodes 2 --disk-size 50 --labels location=$GCP_REGION --spot --gateway-api=standard # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --region $GCP_REGION --machine-type n1-standard-2 --num-nodes 2 --disk-size 50 --labels location=$GCP_REGION --spot --gateway-api=standard
    echo      
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters delete ${GCP_CLUSTER} --region $GCP_REGION # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters delete ${GCP_CLUSTER} --region $GCP_REGION
else
    export STEP="${STEP},3i"   
    echo
    echo "1. Create container cluster" | pv -qL 100
    echo "2. Retrieve the credentials for cluster" | pv -qL 100
    echo "3. Enable current user to set RBAC rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl install --set profile=default -y # to install Istio" | pv -qL 100
    echo
    echo "$ kubectl create namespace \$APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    echo
    echo "$ cat > \$PROJDIR/ingress.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: ingress
spec:
  profile: empty # Do not install CRDs or the control plane
  components:
    ingressGateways:
    - name: ingressgateway
      namespace: \$APPLICATION_NAMESPACE
      enabled: true
      label:
        # Set a unique label for the gateway. This is required to ensure Gateways
        # can select this workload
        istio: ingressgateway
EOF" | pv -qL 100
    echo
    echo "$ \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl install -f \$PROJDIR/ingress.yaml # to install Istio with the Demo profile" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to install addon" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl install --set profile=default -y # to install Istio" | pv -qL 100
    $HOME/istio-${ISTIO_VERSION}/bin/istioctl install --set profile=default -y
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE 2> /dev/null
    echo
    echo "$ cat > $PROJDIR/ingress.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: ingress
spec:
  profile: empty # Do not install CRDs or the control plane
  components:
    ingressGateways:
    - name: ingressgateway
      namespace: $APPLICATION_NAMESPACE
      enabled: true
      label:
        # Set a unique label for the gateway. This is required to ensure Gateways
        # can select this workload
        istio: ingressgateway
EOF" | pv -qL 100
cat > $PROJDIR/ingress.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: ingress
spec:
  profile: empty # Do not install CRDs or the control plane
  components:
    ingressGateways:
    - name: ingressgateway
      namespace: $APPLICATION_NAMESPACE
      enabled: true
      label:
        # Set a unique label for the gateway. This is required to ensure Gateways
        # can select this workload
        istio: ingressgateway
EOF
    echo
    echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl install -f $PROJDIR/ingress.yaml -y # to install Istio with the Demo profile" | pv -qL 100
    $HOME/istio-${ISTIO_VERSION}/bin/istioctl install -f $PROJDIR/ingress.yaml -y
    echo && echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl uninstall --purge # to remove istio" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl uninstall --purge
    echo && echo
    echo "$  kubectl delete namespace istio-system asm-system --ignore-not-found=true # to remove namespace" | pv -qL 100
    kubectl delete namespace istio-system --ignore-not-found=true
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml
else
    export STEP="${STEP},4i"   
    echo
    echo "1. Install Istio" | pv -qL 100
    echo "2. Create namespace" | pv -qL 100
    echo "3. Create istio operator" | pv -qL 100
    echo "4. Configure addons" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ kubectl create namespace \$APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl label namespace \$APPLICATION_NAMESPACE istio-injection=enabled --overwrite # to label namespaces for automatic sidecar injection" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE 2> /dev/null
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled --overwrite # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled --overwrite
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio-injection- # to delete label" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio-injection- 
    echo
    echo "$ kubectl delete namespace $APPLICATION_NAMESPACE # to delete namespace" | pv -qL 100
    kubectl delete namespace $APPLICATION_NAMESPACE 2> /dev/null
else
    export STEP="${STEP},5i"   
    echo
    echo "1. Create namespace" | pv -qL 100
    echo "2. Label namespace" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml # to configure application" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml # to configure application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml # to delete application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml
else
    export STEP="${STEP},6i"   
    echo
    echo "1. Configure application" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml # to create ingress" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml # to create ingress" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml # to delete ingress" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml 
else
    export STEP="${STEP},7i"   
    echo
    echo "1. Configure gateway and virtualservice" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/destination-rule-all.yaml # to apply yaml file" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/destination-rule-all.yaml
    echo 
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to apply yaml file" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/destination-rule-all.yaml
    echo 
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to apply yaml file" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
else
    export STEP="${STEP},8i"   
    echo
    echo "1. Configure subsets" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;
    
"9")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"
    echo
    echo "$ while true; do curl -s -o /dev/null http://\${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-all-v1.yaml # to route all traffic to v1 of each microservice" | pv -qL 100
    echo 
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-jason-v2-v3.yaml # to route requests to jason user" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml # to redirect 50% of traffic to v3" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml # to inject an HTTP delay fault" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-abort.yaml # to inject an HTTP abort fault" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings-route
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        user-agent:
      regex: ^(.*?;)?(iPhone)(;.*)?$
    route:
    - destination:
        host: ratings-iPhone # to route request based on user agent
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: Sidecar
metadata:
  name: ratings
  namespace: bookinfo
spec:
  egress:
  - hosts:
    - \"./*\"
    - \"istio-system/*\" # to limit the set of services that the Envoy proxy can reach
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: bookinfo-ratings-port
spec:
  host: ratings.prod.svc.cluster.local
  trafficPolicy: # Apply to all ports
    portLevelSettings:
    - port:
        number: 80
      loadBalancer:
        simple: LEAST_CONN
    - port:
        number: 9080
      loadBalancer:
        simple: ROUND_ROBIN # load balancing configuration
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
    - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
    timeout: 10s # to set time that an Envoy proxy should wait for replies
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
    - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
    retries:
      attempts: 3
      perTryTimeout: 2s # to configure retry intervals 
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    gcloud config set project $GCP_PROJECT  > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER}  > /dev/null 2>&1
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER  > /dev/null 2>&1
    echo
    echo "$ export INGRESS_HOST=\$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}') # to get ingress IP" | pv -qL 100
    export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-all-v1.yaml
    echo
    echo "$ while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done &
    echo
    echo "$ cat $CFILE # to view yaml file for routing all traffic to v1 of each microservice" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to route all traffic to v1 of each microservice" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-jason-v2-v3.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to route requests to jason user" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    echo "$ while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done &
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to redirect 50% of traffic to v3" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml
    echo
    echo "$ while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done &
    echo
    echo "$ while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage; sleep 1; done &
    echo
    echo "$ cat $CFILE # to view yaml file for injecting an HTTP delay fault" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to inject an HTTP delay fault" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-abort.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file for injecting an HTTP abort fault" | pv -qL 100
    cat $CFILE 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to inject an HTTP abort fault" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE 
    echo
    echo "$ while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage; sleep 1; done &
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings-route
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        user-agent:
      regex: ^(.*?;)?(iPhone)(;.*)?$
    route:
    - destination:
        host: ratings-iPhone # to route request based on user agent
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: Sidecar
metadata:
  name: ratings
  namespace: bookinfo
spec:
  egress:
  - hosts:
    - \"./*\"
    - \"istio-system/*\" # to limit the set of services that the Envoy proxy can reach
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: bookinfo-ratings-port
spec:
  host: ratings.prod.svc.cluster.local
  trafficPolicy: # Apply to all ports
    portLevelSettings:
    - port:
        number: 80
      loadBalancer:
        simple: LEAST_CONN
    - port:
        number: 9080
      loadBalancer:
        simple: ROUND_ROBIN # load balancing configuration
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
    - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
    timeout: 10s # to set time that an Envoy proxy should wait for replies
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
    - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
    retries:
      attempts: 3
      perTryTimeout: 2s # to configure retry intervals 
EOF" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},9i"   
    echo
    echo "1. Explore traffic management" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-10")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"
    echo
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_\${ASM_INSTALL_SCRIPT_VERSION} > \$PROJDIR/asmcli # to download script" | pv -qL 100
    echo
    echo "$ chmod +x \$PROJDIR/asmcli # to make the script executable" | pv -qL 100
    echo
    echo "$ curl -L https://github.com/GoogleContainerTools/kpt/releases/download/v0.39.2/kpt_linux_amd64 > \$PROJDIR/kpt && chmod 755 \$PROJDIR/kpt # to install required apt version" | pv -qL 100
    echo
    echo "$ \$PROJDIR/kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-\${ASM_INSTALL_SCRIPT_VERSION} \$PROJDIR/asm # to download the asm package iap-operator.yaml" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"
    echo
    rm -rf $PROJDIR/* && rm -rf $PROJDIR/*.*
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli # to download script" | pv -qL 100
    curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli
    echo
    echo "$ chmod +x $PROJDIR/asmcli # to make the script executable" | pv -qL 100
    chmod +x $PROJDIR/asmcli
    echo
    echo "$ curl -L https://github.com/GoogleContainerTools/kpt/releases/download/v0.39.2/kpt_linux_amd64 > $PROJDIR/kpt && chmod 755 $PROJDIR/kpt # to install required apt version" | pv -qL 100
    curl -L https://github.com/GoogleContainerTools/kpt/releases/download/v0.39.2/kpt_linux_amd64 > $PROJDIR/kpt && chmod 755 $PROJDIR/kpt
    echo
    echo "$ $PROJDIR/kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-${ASM_INSTALL_SCRIPT_VERSION} $PROJDIR/asm # to download the asm package iap-operator.yaml" | pv -qL 100
    $PROJDIR/kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-${ASM_INSTALL_SCRIPT_VERSION} $PROJDIR/asm
    export PATH=$PROJDIR/istio-${ASM_VERSION}/bin:$PATH > /dev/null 2>&1 # to set ASM path 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10x"
    echo
    echo "$ rm -rf $PROJDIR/asmcli # to delete script" | pv -qL 100
    rm -rf $PROJDIR/asmcli
    echo
    echo "$ rm -rf $PROJDIR/kpt # to delete script" | pv -qL 100
    rm -rf $PROJDIR/kpt
else
    export STEP="${STEP},10i"   
    echo
    echo "1. Download asmcli" | pv -qL 100
    echo "2. Install apt" | pv -qL 100
    echo "3. Download asm package iap-operator.yaml" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-11")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},11i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com mesh.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com mesh.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com mesh.googleapis.com 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT services disable meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com mesh.googleapis.com --force # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services disable meshca.googleapis.com meshtelemetry.googleapis.com meshconfig.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com mesh.googleapis.com --force
else
    export STEP="${STEP},11i"   
    echo
    echo "1. Enable API" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-12")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},12i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters update \$GCP_CLUSTER --workload-pool=\${WORKLOAD_POOL} # to create container cluster" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters update \$GCP_CLUSTER --update-labels=mesh_id=\${MESH_ID},location=\$GCP_REGION # to create container cluster" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters update \$GCP_CLUSTER --update-addons=HttpLoadBalancing=ENABLED # to create container cluster" | pv -qL 100
    echo      
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --region \$GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT container fleet mesh enable # to enable ASM in fleet" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT container fleet memberships register \$GCP_CLUSTER --gke-cluster=\$GCP_REGION/\$GCP_CLUSTER --enable-workload-identity  # to register cluster" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT container fleet mesh update --control-plane automatic --memberships \$GCP_CLUSTER --project \$GCP_PROJECT # to enable automatic control plane management" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},12"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")
    export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster
    export WORKLOAD_POOL=${GCP_PROJECT}.svc.id.goog
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --workload-pool=${WORKLOAD_POOL} # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --workload-pool=${WORKLOAD_POOL} 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --update-labels=mesh_id=${MESH_ID},location=$GCP_REGION # to update container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --update-labels=mesh_id=${MESH_ID},location=$GCP_REGION
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --update-addons=HttpLoadBalancing=ENABLED # to update container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --update-addons=HttpLoadBalancing=ENABLED
    echo      
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION
    echo
    echo "$ gcloud --project $GCP_PROJECT container fleet mesh enable # to enable ASM in fleet" | pv -qL 100
    gcloud --project $GCP_PROJECT container fleet mesh enable
    echo
    echo "$ gcloud --project $GCP_PROJECT container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_REGION/$GCP_CLUSTER --enable-workload-identity  # to register cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_REGION/$GCP_CLUSTER --enable-workload-identity 
    echo
    echo "$ gcloud --project $GCP_PROJECT container fleet mesh update --control-plane automatic --memberships $GCP_CLUSTER --project $GCP_PROJECT # to enable automatic control plane management" | pv -qL 100
    gcloud --project $GCP_PROJECT container fleet mesh update --control-plane automatic --memberships $GCP_CLUSTER --project $GCP_PROJECT
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},12x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")
    export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster
    export WORKLOAD_POOL=${GCP_PROJECT}.svc.id.goog
    echo
    echo "$ gcloud --project $GCP_PROJECT container fleet mesh disable --force # to delete membership" | pv -qL 100
    gcloud --project $GCP_PROJECT container fleet mesh disable --force 
    echo
    echo "$ gcloud --project $GCP_PROJECT container fleet memberships delete $GCP_CLUSTER --quiet # to register cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container fleet memberships delete $GCP_CLUSTER --quiet 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --disable-workload-identity # to disable workload identity" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --disable-workload-identity 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --remove-labels=mesh_id=${MESH_ID},location=$GCP_REGION # to update container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters update $GCP_CLUSTER --remove-labels=mesh_id=${MESH_ID},location=$GCP_REGION
else
    export STEP="${STEP},12i"   
    echo
    echo "1. Create container cluster" | pv -qL 100
    echo "2. Update container cluster" | pv -qL 100
    echo "3. Retrieve the credentials for cluster" | pv -qL 100
    echo "4. Enable ASM in fleet" | pv -qL 100
    echo "5. Enable automatic control plane management" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-13")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},13i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --region \$GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ cat > \$PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
    echo
    echo "$ \$PROJDIR/asmcli experimental mcp-migrate-check -f \$PROJDIR/tracing.yaml # to install ASM" | pv -qL 100
    echo
    echo "$ \$PROJDIR/asmcli install --project_id \$GCP_PROJECT --cluster_name \$GCP_CLUSTER --cluster_location \$CLUSTER_LOCATION --fleet_id \$GCP_PROJECT --managed --use_managed_cni --output_dir \$PROJDIR --enable_all --channel regular --option legacy-default-ingressgateway # to install ASM" | pv -qL 100
    echo
    echo "$ kubectl apply -f  \$HOME/asm-generated-configs/gateways-kubernetes # to migrate ASM" | pv -qL 100
    echo
    echo "$ kubectl label namespace \$APPLICATION_NAMESPACE istio-injection- istio.io/rev=asm-managed --overwrite # to create ingress" | pv -qL 100
    echo
    echo "$ kubectl annotate --overwrite namespace bookinfo mesh.cloud.google.com/proxy='{\"managed\":\"true\"}' # to enable Google to manage data plane" | pv -qL 100
    echo
    echo "$ kubectl apply -n bookinfo -f \$PROJDIR/samples/gateways/istio-ingressgateway # to configure ingress gateway" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},13"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_REGION
    echo
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION
    echo
    echo "$ cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF
    echo
    sudo apt-get install ncat -y > /dev/null 2>&1 
    echo "$ $PROJDIR/asmcli experimental mcp-migrate-check -f $PROJDIR/tracing.yaml # to install ASM" | pv -qL 100
    $PROJDIR/asmcli experimental mcp-migrate-check -f $PROJDIR/tracing.yaml
    echo
    echo "$ $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --managed --use_managed_cni --output_dir $PROJDIR --enable_all --channel regular # to install ASM" | pv -qL 100
    $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --managed --use_managed_cni --output_dir $PROJDIR --enable_all --channel regular
    echo
    echo "$ kubectl apply -f  $HOME/asm-generated-configs/gateways-kubernetes # to migrate ASM" | pv -qL 100
    kubectl apply -f  $HOME/asm-generated-configs/gateways-kubernetes
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio-injection- istio.io/rev=asm-managed --overwrite # to label ingress" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio-injection- istio.io/rev=asm-managed --overwrite
    echo
    echo "$ kubectl annotate --overwrite namespace $APPLICATION_NAMESPACE mesh.cloud.google.com/proxy='{\"managed\":\"true\"}' # to enable Google to manage data plane" | pv -qL 100
    kubectl annotate --overwrite namespace $APPLICATION_NAMESPACE mesh.cloud.google.com/proxy='{"managed":"true"}'
    echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f $PROJDIR/samples/gateways/istio-ingressgateway # to configure ingress gateway" | pv -qL 100
    kubectl apply -n $APPLICATION_NAMESPACE -f $PROJDIR/samples/gateways/istio-ingressgateway
    echo
    echo "$ kubectl rollout restart deployment -n $APPLICATION_NAMESPACE # to perform a rolling upgrade of deployments to update proxies to use new ASM version" | pv -qL 100
    kubectl rollout restart deployment -n $APPLICATION_NAMESPACE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},13x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_REGION
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev # to remove labels" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev-
    echo
    echo "$ kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot # to remove webhooks" | pv -qL 100
    kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge # to remove the in-cluster control plane" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge
    echo && echo
    echo "$  kubectl delete namespace istio-system asm-system --ignore-not-found=true # to remove namespace" | pv -qL 100
     kubectl delete namespace istio-system asm-system --ignore-not-found=true
else
    export STEP="${STEP},13i"   
    echo
    echo "1. Retrieve cluster credentials" | pv -qL 100
    echo "2. Install ASM" | pv -qL 100
    echo "3. Migrate ASM" | pv -qL 100
    echo "4. Label Ingress" | pv -qL 100
    echo "5. Enable Google to manage data plane" | pv -qL 100
    echo "6. Configure ingress gateway" | pv -qL 100
    echo "7. Perform a rolling upgrade of deployments" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-14")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},14i"
    echo
    echo "$ \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl x uninstall --purge -y # to uninstall Istio" | pv -qL 100
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl delete namespace istio-system # delete namespace"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},14"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl x uninstall --purge -y # to uninstall Istio" | pv -qL 100
    $HOME/istio-${ISTIO_VERSION}/bin/istioctl x uninstall --purge -y
    echo && echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to install addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to install addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to install addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to install addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml
    echo
    echo "$ kubectl delete namespace istio-system # delete namespace"
    kubectl delete namespace istio-system
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},14x"   
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},14i"   
    echo
    echo "1. Uninstall Istio" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-15")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},15i"
    echo
    echo "$ export INGRESS_HOST=\$(kubectl -n $APPLICATION_NAMESPACE get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}') # to get ingress IP" | pv -qL 100
    echo
    echo "$ while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-all-v1.yaml
    echo
    echo "$ cat $CFILE # to view yaml file for routing all traffic to v1 of each microservice" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to route all traffic to v1 of each microservice" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-jason-v2-v3.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to route requests to jason user" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to redirect 50% of traffic to v3" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml
    echo
    echo "$ cat $CFILE # to view yaml file for injecting an HTTP delay fault" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to inject an HTTP delay fault" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-abort.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file for injecting an HTTP abort fault" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to inject an HTTP abort fault" | pv -qL 100
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from details to productpage service" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  mtls:
    mode: STRICT # to strictly enforce mTLS on productpage microservice
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from details to productpage service" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE delete PeerAuthentication productpage # to delete configuration" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
 name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.5/security/tools/jwt/samples/jwks.json # to enforce end-user (origin) authentication for the productpage service, using JSON Web Tokens (JWT)
EOF" | pv -qL 100
    echo
    echo "$ export TOKEN=\$(curl -k https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s); echo \$TOKEN # to set a local TOKEN variable" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the productpage with a valid JWT" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage without a JWT" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header \"Authorization: Bearer helloworld\" -s -w '%{http_code}\n' # to curl the productpage with an invalid JWT" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [testing@secure.istio.io/testing@secure.istio.io] # to configure an authorization policy that requires a JWT on all requests
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage without a JWT" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the productpage with a valid JWT" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - when:
    - key: request.headers[hello]
      values: [world] # to only allowing requests to the productpage that have a specific HTTP header (hello:world)
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage without the hello header" | pv -qL 100 
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl --header \"hello:world\" http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage with the hello:world header" | pv -qL 100
    echo
    echo "$ kubectl delete RequestAuthentication productpage -n \$APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    echo
    echo "$ kubectl delete AuthorizationPolicy require-jwt -n \$APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    echo
    echo "$ kubectl delete AuthorizationPolicy productpage -n \$APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},15"
    gcloud config set project $GCP_PROJECT  > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER}  > /dev/null 2>&1
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER  > /dev/null 2>&1
    echo
    echo "$ export INGRESS_HOST=\$(kubectl -n $APPLICATION_NAMESPACE get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}') # to get ingress IP" | pv -qL 100
    export INGRESS_HOST=$(kubectl -n $APPLICATION_NAMESPACE get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-all-v1.yaml
    echo
    echo "$ while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done &
    echo
    echo "$ cat $CFILE # to view yaml file for routing all traffic to v1 of each microservice" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to route all traffic to v1 of each microservice" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-jason-v2-v3.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to route requests to jason user" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    echo "$ while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done &
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to redirect 50% of traffic to v3" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml
    echo
    echo "$ while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done &
    echo
    echo "$ while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage; sleep 1; done &
    echo
    echo "$ cat $CFILE # to view yaml file for injecting an HTTP delay fault" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to inject an HTTP delay fault" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    export PFILE=$CFILE
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/virtual-service-ratings-test-abort.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file for injecting an HTTP abort fault" | pv -qL 100
    cat $CFILE 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to inject an HTTP abort fault" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE 
    echo
    echo "$ while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -H 'end-user: jason' -o /dev/null http://${INGRESS_HOST}/productpage; sleep 1; done &
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE # to delete rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $CFILE
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from details to productpage service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  mtls:
    mode: STRICT # to strictly enforce mTLS on productpage microservice
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  mtls:
    mode: STRICT # to strictly enforce mTLS on productpage microservice
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from details to productpage service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n'
    sleep 5
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete PeerAuthentication productpage # to delete configuration" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete PeerAuthentication productpage
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
 name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.5/security/tools/jwt/samples/jwks.json # to enforce end-user (origin) authentication for the productpage service, using JSON Web Tokens (JWT)
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
 name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.5/security/tools/jwt/samples/jwks.json # to enforce end-user (origin) authentication for the productpage service, using JSON Web Tokens (JWT)
EOF
    echo
    echo "$ export TOKEN=\$(curl -k https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s); echo \$TOKEN # to set a local TOKEN variable" | pv -qL 100
    export TOKEN=$(curl -k https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s); echo $TOKEN
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the productpage with a valid JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header "Authorization: Bearer $TOKEN" -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage without a JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header \"Authorization: Bearer helloworld\" -s -w '%{http_code}\n' # to curl the productpage with an invalid JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header "Authorization: Bearer helloworld" -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [testing@secure.istio.io/testing@secure.istio.io] # to configure an authorization policy that requires a JWT on all requests
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [testing@secure.istio.io/testing@secure.istio.io] # to configure an authorization policy that requires a JWT on all requests
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage without a JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the productpage with a valid JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null --header "Authorization: Bearer $TOKEN" -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - when:
    - key: request.headers[hello]
      values: [world] # to only allowing requests to the productpage that have a specific HTTP header (hello:world)
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - when:
    - key: request.headers[hello]
      values: [world] # to only allowing requests to the productpage that have a specific HTTP header (hello:world)
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage without the hello header" | pv -qL 100 
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl --header \"hello:world\" http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n' # to curl the productpage with the hello:world header" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=details -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl --header "hello:world" http://productpage:9080/ -o /dev/null -s -w '%{http_code}\n'
    echo
    echo "$ kubectl delete RequestAuthentication productpage -n $APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    kubectl delete RequestAuthentication productpage -n $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl delete AuthorizationPolicy require-jwt -n $APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    kubectl delete AuthorizationPolicy require-jwt -n $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl delete AuthorizationPolicy productpage -n $APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    kubectl delete AuthorizationPolicy productpage -n $APPLICATION_NAMESPACE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},15x"   
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},15i"   
    echo
    echo "1. Explore Istio traffic management and security" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done

