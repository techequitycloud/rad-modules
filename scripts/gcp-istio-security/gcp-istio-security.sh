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
##############  Explore Istio HTTPBin Microservice Application   ################
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

mkdir -p `pwd`/gcp-istio-security > /dev/null 2>&1
export SCRIPTNAME=gcp-istio-security.sh
export PROJDIR=`pwd`/gcp-istio-security

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export ISTIO_VERSION=1.24.2
export GCP_REGION=us-central1
export GCP_CLUSTER=gke-cluster
EOF
source $PROJDIR/.env
fi

export APPLICATION_NAMESPACE=httpbin
export APPLICATION_NAME=httpbin

# Display menu options
while :
do
clear
cat<<EOF
==============================================================
Menu for exploring Istio Resiliency and Security Features
--------------------------------------------------------------
Please enter number to select your choice:
 (1) Install tools 
 (2) Enable APIs
 (3) Create Kubernetes cluster
 (4) Install Istio
 (5) Configure namespace for automatic sidecar injection
 (6) Explore traffic mirroring 
 (7) Explore circuit breaking 
 (8) Explore security 
 (Q) Quit
--------------------------------------------------------------
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
export ISTIO_VERSION=$ISTIO_VERSION
export GCP_REGION=$GCP_REGION
export GCP_CLUSTER=$GCP_CLUSTER
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
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
                            sleep 5
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
export ISTIO_VERSION=1.24.2
export GCP_REGION=us-central1
export GCP_CLUSTER=gke-cluster
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
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
    echo "$ curl -L \"https://github.com/istio/istio/releases/download/\${ISTIO_VERSION}/istio-\${ISTIO_VERSION}-linux-amd64.tar.gz\" | tar xz -C \$HOME # to download Istio" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    cd $HOME > /dev/null 2>&1
    echo
    echo "$ curl -L \"https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz\" | tar xz -C $HOME # to download Istio" | pv -qL 100
    curl -L "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz" | tar xz -C $HOME 
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
    gcloud --project $GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com
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
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$GCP_CLUSTER --region \$GCP_REGION --machine-type \"n1-standard-2\" --num-nodes \"3\" --disk-size \"50\" --labels location=\$GCP_REGION --spot --gateway-api=standard # to create container cluster" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --region \$GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules for Istio" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --region $GCP_REGION --machine-type \"n1-standard-2\" --num-nodes \"3\" --disk-size \"50\" --labels location=$GCP_REGION --spot --gateway-api=standard # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --region $GCP_REGION --machine-type "n1-standard-2" --num-nodes "3" --disk-size "50" --labels location=$GCP_REGION --spot --gateway-api=standard
    echo
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules for Istio" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters delete $GCP_CLUSTER --region $GCP_REGION # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters delete $GCP_CLUSTER --region $GCP_REGION
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
    echo "$ \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl install --set profile=default -y # to install Istio with the Demo profile" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl install --set profile=default -y # to install Istio with the Demo profile" | pv -qL 100
    $HOME/istio-${ISTIO_VERSION}/bin/istioctl install --set profile=default -y
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl uninstall --purge # to uninstall Istio" | pv -qL 100
    $HOME/istio-${ISTIO_VERSION}/bin/istioctl uninstall --purge 
    echo && echo
    echo "$  kubectl delete namespace istio-system --ignore-not-found=true # to remove namespace" | pv -qL 100
    kubectl delete namespace istio-system --ignore-not-found=true
else
    export STEP="${STEP},4i"
    echo
    echo "1. Install Istio" | pv -qL 100
fi
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
    echo "$ kubectl label namespace \$APPLICATION_NAMESPACE istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER > /dev/null 2>&1
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION > /dev/null 2>&1 
    echo
    echo "$ kubectl delete namespace $APPLICATION_NAMESPACE # to delete namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE 2> /dev/null
else
    export STEP="${STEP},5i"
    echo
    echo "1. Create and label namespace" | pv -qL 100
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
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml # to create ingress" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: [\"gunicorn\", \"--access-logfile\", \"-\", \"-b\", \"0.0.0.0:80\", \"httpbin:app\"]
        ports:
        - containerPort: 80
EOF" | pv -qL 100
    echo 
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v2
  template:
    metadata:
      labels:
        app: httpbin
        version: v2
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: [\"gunicorn\", \"--access-logfile\", \"-\", \"-b\", \"0.0.0.0:80\", \"httpbin:app\"]
        ports:
        - containerPort: 80
EOF" | pv -qL 100
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n \$APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: httpbin
EOF" | pv -qL 100
    echo 
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: curlimages/curl
        command: [\"/bin/sleep\",\"3650d\"]
        imagePullPolicy: IfNotPresent
EOF" | pv -qL 100
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n \$APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$SLEEP_POD -c sleep -- curl -s http://httpbin:8000/headers # to send some traffic to the service" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE logs \$V1_POD -c httpbin # to view logs for v1 of the httpbin pods" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE logs \$V2_POD -c httpbin # to tail logs for v2 of the httpbin pods" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
    mirror:
      host: httpbin
      subset: v2
    mirrorPercentage:
      value: 100.0
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec -it \$SLEEP_POD -c sleep -- sh -c 'for i in \`seq 1 5\`; do curl http://httpbin:8000/headers; done' # to send 5x traffic to the service" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE logs \$V1_POD -c httpbin # to view logs for v1 of the httpbin pods" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE logs \$V2_POD -c httpbin # to tail logs for v2 of the httpbin pods" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # gateway configuration for external HTTPS ingress traffic
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: ext-host-gwy
spec:
  selector:
    app: my-gateway-controller
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - ext-host.example.com
    tls:
      mode: SIMPLE
      credentialName: ext-host-cert
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to add ext-svc.example.com external dependency to Istio�s service registry
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: svc-entry
spec:
  hosts:
  - ext-svc.example.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to use mutual TLS to secure the connection to ext-svc.example.com external service
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ext-res-dr
spec:
  host: ext-svc.example.com
  trafficPolicy:
    tls:
      mode: MUTUAL
      clientCertificate: /etc/certs/myclientcert.pem
      privateKey: /etc/certs/client_private_key.pem
      caCertificates: /etc/certs/rootcacerts.pem
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER > /dev/null 2>&1
    export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo
    cd $HOME/istio-${ISTIO_VERSION} > /dev/null 2>&1 # change to istio directory
    echo "$ cat samples/httpbin/httpbin-gateway.yaml # to view gateway and virtual service" | pv -qL 100
    cat samples/httpbin/httpbin-gateway.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml # to create ingress" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: [\"gunicorn\", \"--access-logfile\", \"-\", \"-b\", \"0.0.0.0:80\", \"httpbin:app\"]
        ports:
        - containerPort: 80
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: ["gunicorn", "--access-logfile", "-", "-b", "0.0.0.0:80", "httpbin:app"]
        ports:
        - containerPort: 80
EOF
    echo 
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v2
  template:
    metadata:
      labels:
        app: httpbin
        version: v2
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: [\"gunicorn\", \"--access-logfile\", \"-\", \"-b\", \"0.0.0.0:80\", \"httpbin:app\"]
        ports:
        - containerPort: 80
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v2
  template:
    metadata:
      labels:
        app: httpbin
        version: v2
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: ["gunicorn", "--access-logfile", "-", "-b", "0.0.0.0:80", "httpbin:app"]
        ports:
        - containerPort: 80
EOF
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: httpbin
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: httpbin
EOF
    echo 
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: curlimages/curl
        command: [\"/bin/sleep\",\"3650d\"]
        imagePullPolicy: IfNotPresent
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep","3650d"]
        imagePullPolicy: IfNotPresent
EOF
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
EOF
    export SLEEP_POD=$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=sleep -o jsonpath={.items..metadata.name}) 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec $SLEEP_POD -c sleep -- curl -s http://httpbin:8000/headers # to send some traffic to the service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $SLEEP_POD -c sleep -- curl -s http://httpbin:8000/headers
    echo
    export V1_POD=$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=httpbin,version=v1 -o jsonpath={.items..metadata.name}) # to set v1 POD env variable.
    export V2_POD=$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=httpbin,version=v2 -o jsonpath={.items..metadata.name}) # to set v2 POD env variable.
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE logs $V1_POD -c httpbin # to view logs for v1 of the httpbin pods" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE logs $V1_POD -c httpbin
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE logs $V2_POD -c httpbin # to tail logs for v2 of the httpbin pods" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE logs $V2_POD -c httpbin
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
    mirror:
      host: httpbin
      subset: v2
    mirrorPercentage:
      value: 100.0
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
    mirror:
      host: httpbin
      subset: v2
    mirrorPercentage:
      value: 100.0
EOF
    sleep 15
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec -it $SLEEP_POD -c sleep -- sh -c 'for i in `seq 1 5`; do curl http://httpbin:8000/headers; done' # to send 5x traffic to the service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec -it $SLEEP_POD -c sleep -- sh -c 'for i in `seq 1 5`; do curl http://httpbin:8000/headers; done'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE logs $V1_POD -c httpbin # to view logs for v1 of the httpbin pods" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE logs $V1_POD -c httpbin
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE logs $V2_POD -c httpbin # to tail logs for v2 of the httpbin pods" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE logs $V2_POD -c httpbin
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ kubectl delete namespace $APPLICATION_NAMESPACE # to delete namespace" | pv -qL 100
    kubectl delete namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"        
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},6i"
    echo
    echo "1. Explore traffic management" | pv -qL 100
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
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml # to create ingress" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin.yaml # to deploy httpbin sample" | pv -qL 100
    echo
    echo "$ curl -I -HHost:* http://\$INGRESS_HOST/status/200 # to access the httpbin service using curl" | pv -qL 100
    echo 
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f samples/httpbin/sample-client/fortio-deploy.yaml # to deploy the FORTIO client" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec -it \$FORTIO_POD  -c fortio -- /usr/bin/fortio load -curl http://httpbin:8000/get # to invoke the service with one connection and send 1 request" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec -it \$FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get # to invoke the service with 2 concurrent connections (-c 2) and send 20 requests (-n 20)" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec -it \$FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -n 30 -loglevel Warning http://httpbin:8000/get # to invoke the service with 3 concurrent connections (-c 3) and send 30 requests (-n 30)" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: \${APPLICATION_NAME}
spec:
  host: \${APPLICATION_NAME}
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 3m
      maxEjectionPercent: 100
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec -it \$FORTIO_POD  -c fortio -- /usr/bin/fortio load -curl http://httpbin:8000/get # to invoke the service with one connection and send 1 request" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec -it \$FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get # to invoke the service with 2 concurrent connections (-c 2) and send 20 requests (-n 20)" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec -it \$FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -n 30 -loglevel Warning http://httpbin:8000/get # to invoke the service with 3 concurrent connections (-c 3) and send 30 requests (-n 30)" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$FORTIO_POD -c istio-proxy -- pilot-agent request GET stats | grep httpbin | grep pending # to query the istio-proxy stats" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER > /dev/null 2>&1
    export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo
    cd $HOME/istio-${ISTIO_VERSION} > /dev/null 2>&1 # change to istio directory
    echo "$ cat samples/httpbin/httpbin-gateway.yaml # to view gateway and virtual service" | pv -qL 100
    cat samples/httpbin/httpbin-gateway.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml # to create ingress" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo
    export CFILE=samples/httpbin/httpbin.yaml
    echo
    echo "$ cat $CFILE # to view yaml"
    cat $CFILE
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to deploy httpbin sample" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ curl -I -HHost:* http://$INGRESS_HOST/status/200 # to access the httpbin service using curl" | pv -qL 100
    curl -I -HHost:* http://$INGRESS_HOST/status/200
    export PFILE=$CFILE
    export CFILE=samples/httpbin/sample-client/fortio-deploy.yaml
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cat $CFILE # to view yaml" | pv -qL 100
    cat $CFILE
    echo 
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to deploy the FORTIO client" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export FORTIO_POD=$(kubectl -n $APPLICATION_NAMESPACE get pods -lapp=fortio -o 'jsonpath={.items[0].metadata.name}') # to set environment variable for client POD.
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -curl http://httpbin:8000/get # to invoke the service with one connection and send 1 request" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -curl http://httpbin:8000/get
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get # to invoke the service with 2 concurrent connections (-c 2) and send 20 requests (-n 20)" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -n 30 -loglevel Warning http://httpbin:8000/get # to invoke the service with 3 concurrent connections (-c 3) and send 30 requests (-n 30)" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -n 30 -loglevel Warning http://httpbin:8000/get
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ${APPLICATION_NAME}
spec:
  host: ${APPLICATION_NAME}
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 3m
      maxEjectionPercent: 100
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ${APPLICATION_NAME}
spec:
  host: ${APPLICATION_NAME}
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 3m
      maxEjectionPercent: 100
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export FORTIO_POD=$(kubectl -n $APPLICATION_NAMESPACE get pods -lapp=fortio -o 'jsonpath={.items[0].metadata.name}') # to set environment variable for client POD.
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -curl http://httpbin:8000/get # to invoke the service with one connection and send 1 request" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -curl http://httpbin:8000/get
    echo
    echo "$ sleep 15 # to wait for 15 secs and load test" | pv -qL 100
    sleep 15
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get # to invoke the service with 2 concurrent connections (-c 2) and send 20 requests (-n 20)" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get
    echo
    echo "$ sleep 15 # to wait for 15 secs and load test" | pv -qL 100
    sleep 15
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -n 30 -loglevel Warning http://httpbin:8000/get # to invoke the service with 3 concurrent connections (-c 3) and send 30 requests (-n 30)" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec -it $FORTIO_POD  -c fortio -- /usr/bin/fortio load -c 3 -qps 0 -n 30 -loglevel Warning http://httpbin:8000/get
    echo
    echo "$ sleep 15 # to wait for 15 secs and display statistics" | pv -qL 100
    sleep 15 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec $FORTIO_POD -c istio-proxy -- pilot-agent request GET stats | grep httpbin | grep pending # to query the istio-proxy stats" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $FORTIO_POD -c istio-proxy -- pilot-agent request GET stats | grep httpbin | grep pending
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl delete namespace $APPLICATION_NAMESPACE # to delete namespace" | pv -qL 100
    kubectl delete namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"        
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},7i"
    echo
    echo "1. Explore traffic management" | pv -qL 100
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
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml # to create ingress" | pv -qL 100
    echo
    echo "$ kubectl create namespace foo # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl label namespace foo istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    echo
    echo "$ kubectl create namespace bar # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl label namespace bar istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    echo
    echo "$ kubectl create namespace legacy # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl -n foo apply -f samples/httpbin/httpbin.yaml # to deploy httpbin" | pv -qL 100
    echo
    echo "$ kubectl -n foo apply -f samples/sleep/sleep.yaml # to deploy sleep" | pv -qL 100
    echo 
    echo "$ kubectl -n bar apply -f samples/sleep/sleep.yaml # to deploy sleep" | pv -qL 100
    echo
    echo "$ kubectl -n legacy apply -f samples/sleep/sleep.yaml # to deploy sleep" | pv -qL 100
    echo
    echo "$ for from in \"foo\" \"bar\" \"legacy\"; do kubectl exec \$(kubectl get pod -l app=sleep -n \${from} -o jsonpath={.items..metadata.name}) -c sleep -n \${from} -- curl http://httpbin.foo:8000/headers -s -w \"sleep.\${from} to httpbin.foo: %{http_code}\\n\\n \"; done # to send HTTP request from any sleep pod in foo, bar or legacy namespace to httpbin in foo namespace"  | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin-istio-client-mtls
spec:
  host: httpbin.foo.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: PERMISSIVE
EOF" | pv -qL 100
    echo
    echo "$ for from in \"foo\" \"bar\" \"legacy\"; do kubectl exec \$(kubectl get pod -l app=sleep -n \${from} -o jsonpath={.items..metadata.name}) -c sleep -n \${from} -- curl http://httpbin.foo:8000/headers -s -w \"sleep.\${from} to httpbin.foo: %{http_code}, \"; done # to send HTTP request from any sleep pod in foo, bar or legacy namespace to httpbin in foo namespace"  | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: STRICT
EOF" | pv -qL 100
    echo
    echo "$ for from in \"foo\" \"bar\" \"legacy\"; do kubectl exec \$(kubectl get pod -l app=sleep -n \${from} -o jsonpath={.items..metadata.name}) -c sleep -n \${from} -- curl http://httpbin.foo:8000/headers -s -w \"sleep.\${from} to httpbin.foo: %{http_code}, \"; done # to send HTTP request from any sleep pod in foo, bar or legacy namespace to httpbin in foo namespace"  | pv -qL 100
    echo
    echo "$ kubectl -n foo delete PeerAuthentication httpbin-authentication # to delete policy" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to allow workload to accept requests with a JWT issued by testing@secure.istio.io
apiVersion: \"security.istio.io/v1beta1\"
kind: \"RequestAuthentication\"
metadata:
  name: \"jwt-request-auth\"
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: \"testing@secure.istio.io\"
    jwksUri: \"https://raw.githubusercontent.com/istio/istio/release-1.8/security/tools/jwt/samples/jwks.json\"
EOF" | pv -qL 100
    echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -H \"Authorization: Bearer invalidToken\" -w \"%{http_code}\\n\\n\" # to verify request with invalid JWT is denied" | pv -qL 100
    echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -w \"%{http_code}\\n\\n\" # to verify request without a JWT is allowed" | pv -qL 100
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to require requests to have a valid JWT 
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [\"testing@secure.istio.io/testing@secure.istio.io\"]
EOF" | pv -qL 100
    echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -H \"Authorization: Bearer \$TOKEN\" -w \"%{http_code}\\n\\n\" # to verify that a request with a valid JWT is allowed" | pv -qL 100
    echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -w \"%{http_code}\\n\\n\" # to verify request without a JWT is denied" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to limit HTTP requests to GET to /ip endpoint
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: [\"testing@secure.istio.io/testing@secure.istio.io\"]
    to:
    - operation:
        methods: [\"GET\"]
        paths: [\"/ip\"]
EOF" | pv -qL 100
    echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/ip\" -s -o /dev/null -H \"Authorization: Bearer \$TOKEN\" -w \"%{http_code}\\n\\n\" # to verify request to /ip endpoint works" | pv -qL 100
    echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -H \"Authorization: Bearer \$TOKEN\" -w \"%{http_code}\\n\\n\" # to verify request to /headers endpoint is denied" | pv -qL 100
    echo
    echo "$ kubectl delete AuthorizationPolicy require-jwt -n foo # to delete policy"
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to disables mutual TLS on port 80 only 
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
  namespace: foo
spec:
  selector:
     matchLabels:
       app: httpbin
  portLevelMtls:
    80:
      mode: DISABLE
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to allow cluster.local/ns/default/sa/sleep service account and dev namespace to access workloads when requests have a valid JWT token
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: ALLOW
 rules:
 - from:
   - source:
       principals: [\"cluster.local/ns/default/sa/sleep\"]
   - source:
       namespaces: [\"dev\"]
   to:
   - operation:
       methods: [\"GET\"]
   when:
   - key: request.auth.claims[iss]
     values: [\"https://accounts.google.com\"]
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to deny requests if the source is not the foo namespace
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin-deny
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: DENY
 rules:
 - from:
   - source:
       notNamespaces: [\"foo\"]
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f - # to allow \"GET\" and \"HEAD\" access to the workload
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-read
spec:
  selector:
    matchLabels:
      app: products
  action: ALLOW
  rules:
  - to:
    - operation:
         methods: [\"GET\", \"HEAD\"]
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f - # to allow access at paths with /test/* prefix or */info suffix
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tester
spec:
  selector:
    matchLabels:
      app: products
  action: ALLOW
  rules:
  - to:
    - operation:
        paths: [\"/test/*\", \"*/info\"]
EOF" | pv -qL 100
    echo        
    echo "$ cat <<EOF | kubectl apply -f - # to require a valid request principals, which is derived from JWT authentication, if the request path is not /healthz
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: disable-jwt-for-healthz
spec:
  selector:
    matchLabels:
      app: products
  action: ALLOW
  rules:
  - to:
    - operation:
        notPaths: [\"/healthz\"]
    from:
    - source:
        requestPrincipals: [\"*\"]
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl -n foo apply -f - # to deny request if not from foo namespace
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin-deny
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: DENY
 rules:
 - from:
   - source:
       notNamespaces: [\"foo\"]
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f - # to deny request to /admin path for requests without request principals
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: enable-jwt-for-admin
spec:
  selector:
    matchLabels:
      app: products
  action: DENY
  rules:
  - to:
    - operation:
        paths: [\"/admin\"]
    from:
    - source:
        notRequestPrincipals: [\"*\"]
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f - # ALLOW policy that matches nothing. Start with allow-nothing policy and incrementally add ALLOW policies to open access to the workload
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
spec:
  action: ALLOW
  # the rules field is not specified, and the policy will never match.
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f - # DENY policy that explicitly denies all access. DENY policy takes precedence over the ALLOW policy. Useful to temporarily disable all access.
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
spec:
  action: DENY
  # the rules field has an empty rule, and the policy will always match.
  rules:
  - {}
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f - # ALLOW policy that allows full access to the workload. Useful to temporarily expose full access to the workload. Request could still be denied due to CUSTOM and DENY policies.
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-all
spec:
  action: ALLOW
  # This matches everything.
  rules:
  - {}
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f - # to include a condition that request.headers[version] is either "v1" or "v2"
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
 namespace: foo
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: ALLOW
 rules:
 - from:
   - source:
       principals: [\"cluster.local/ns/default/sa/sleep\"]
   to:
   - operation:
       methods: [\"GET\"]
   when:
   - key: request.headers[version]
     values: [\"v1\", \"v2\"]
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_REGION}_${GCP_CLUSTER} > /dev/null 2>&1
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER > /dev/null 2>&1
    export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo
    cd $HOME/istio-${ISTIO_VERSION} > /dev/null 2>&1 # change to istio directory
    echo "$ cat samples/httpbin/httpbin-gateway.yaml # to view gateway and virtual service" | pv -qL 100
    cat samples/httpbin/httpbin-gateway.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml # to create ingress" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f samples/httpbin/httpbin-gateway.yaml
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl create namespace foo # to create namespace" | pv -qL 100
    kubectl create namespace foo 2>/dev/null
    echo
    echo "$ kubectl label namespace foo istio-injection=enabled --overwrite # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace foo istio-injection=enabled --overwrite
    echo
    echo "$ kubectl create namespace bar # to create namespace" | pv -qL 100
    kubectl create namespace bar  2>/dev/null
    echo
    echo "$ kubectl label namespace bar istio-injection=enabled --overwrite # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace bar istio-injection=enabled --overwrite
    echo
    echo "$ kubectl create namespace legacy # to create namespace" | pv -qL 100
    kubectl create namespace legacy 2>/dev/null
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export CFILE=samples/httpbin/httpbin.yaml
    echo
    echo "$ cat $CFILE # to view yaml" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n foo apply -f $CFILE # to deploy httpbin" | pv -qL 100
    kubectl -n foo apply -f $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export CFILE=samples/sleep/sleep.yaml
    echo
    echo "$ cat $CFILE # to view yaml" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n foo apply -f $CFILE # to deploy sleep" | pv -qL 100
    kubectl -n foo apply -f $CFILE
    echo 
    echo "$ kubectl -n bar apply -f $CFILE # to deploy sleep" | pv -qL 100
    kubectl -n bar apply -f $CFILE
    echo
    echo "$ kubectl -n legacy apply -f $CFILE # to deploy sleep" | pv -qL 100
    kubectl -n legacy apply -f $CFILE
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n foo # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n foo
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n bar # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n bar
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n legacy # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n legacy
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ for from in \"foo\" \"bar\" \"legacy\"; do kubectl exec \$(kubectl get pod -l app=sleep -n \${from} -o jsonpath={.items..metadata.name}) -c sleep -n \${from} -- curl http://httpbin.foo:8000/headers -s -w \"sleep.\${from} to httpbin.foo: %{http_code}\\n\\n\"; done # to send HTTP request from any sleep pod in foo, bar or legacy namespace to httpbin in foo namespace"  | pv -qL 100
    for from in "foo" "bar" "legacy"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.foo:8000/headers -s -w "sleep.${from} to httpbin.foo: %{http_code}\n\n"; done
    echo && echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cat <<EOF | kubectl apply -n foo -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin-istio-client-mtls
spec:
  host: httpbin.foo.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF" | pv -qL 100
cat <<EOF | kubectl apply -n foo -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin-istio-client-mtls
spec:
  host: httpbin.foo.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: PERMISSIVE
EOF" | pv -qL 100
cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: PERMISSIVE
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ for from in \"foo\" \"bar\" \"legacy\"; do kubectl exec \$(kubectl get pod -l app=sleep -n \${from} -o jsonpath={.items..metadata.name}) -c sleep -n \${from} -- curl http://httpbin.foo:8000/headers -s -w \"sleep.\${from} to httpbin.foo: %{http_code}\\n\\n\"; done # to send HTTP request from any sleep pod in foo, bar or legacy namespace to httpbin in foo namespace"  | pv -qL 100
    for from in "foo" "bar" "legacy"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.foo:8000/headers -s -w "sleep.${from} to httpbin.foo: %{http_code}\n\n"; done
    echo && echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: STRICT
EOF" | pv -qL 100
cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: STRICT
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ for from in \"foo\" \"bar\" \"legacy\"; do kubectl exec \$(kubectl get pod -l app=sleep -n \${from} -o jsonpath={.items..metadata.name}) -c sleep -n \${from} -- curl http://httpbin.foo:8000/headers -s -w \"sleep.\${from} to httpbin.foo: %{http_code}\\n\\n\"; done # to send HTTP request from any sleep pod in foo, bar or legacy namespace to httpbin in foo namespace"  | pv -qL 100
    for from in "foo" "bar" "legacy"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.foo:8000/headers -s -w "sleep.${from} to httpbin.foo: %{http_code}\n\n"; done
    echo && echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n foo delete PeerAuthentication httpbin-authentication # to delete policy" | pv -qL 100
    kubectl -n foo delete PeerAuthentication httpbin-authentication
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to allow workload to accept requests with a JWT issued by testing@secure.istio.io
apiVersion: \"security.istio.io/v1beta1\"
kind: \"RequestAuthentication\"
metadata:
  name: \"jwt-request-auth\"
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: \"testing@secure.istio.io\"
    jwksUri: \"https://raw.githubusercontent.com/istio/istio/release-1.8/security/tools/jwt/samples/jwks.json\"
EOF" | pv -qL 100
    cat <<EOF | kubectl apply -n foo -f - # to allow workload to accept requests with a JWT issued by testing@secure.istio.io
apiVersion: "security.istio.io/v1beta1"
kind: "RequestAuthentication"
metadata:
  name: "jwt-request-auth"
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.8/security/tools/jwt/samples/jwks.json"
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -H \"Authorization: Bearer invalidToken\" -w \"%{http_code}\\n\\n\" # to verify request with invalid JWT is denied" | pv -qL 100
    kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin:8000/headers" -s -o /dev/null -H "Authorization: Bearer invalidToken" -w "%{http_code}\n\n"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -w \"%{http_code}\\n\\n\" # to verify request without a JWT is allowed" | pv -qL 100
    kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin:8000/headers" -s -o /dev/null -w "%{http_code}\n\n"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to require requests to have a valid JWT 
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [\"testing@secure.istio.io/testing@secure.istio.io\"]
EOF" | pv -qL 100
cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
EOF
    sleep 10
    echo
    echo "$ export TOKEN=\$(curl https://raw.githubusercontent.com/istio/istio/release-1.8/security/tools/jwt/samples/demo.jwt -s) && echo \"\$TOKEN\" | cut -d '.' -f2 - | base64 --decode - # to download a legitimate JWT" | pv -qL 100
    export TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.8/security/tools/jwt/samples/demo.jwt -s) && echo "$TOKEN" | cut -d '.' -f2 - | base64 --decode -
    echo && echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -H \"Authorization: Bearer \$TOKEN\" -w \"%{http_code}\\n\" # to verify that a request with a valid JWT is allowed" | pv -qL 100
    kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin:8000/headers" -s -o /dev/null -H "Authorization: Bearer $TOKEN" -w "%{http_code}\n"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -w \"%{http_code}\\n\" # to verify request without a JWT is denied" | pv -qL 100
    kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin:8000/headers" -s -o /dev/null -w "%{http_code}\n"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to limit HTTP requests to GET to /ip endpoint
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: [\"testing@secure.istio.io/testing@secure.istio.io\"]
    to:
    - operation:
        methods: [\"GET\"]
        paths: [\"/ip\"]
EOF" | pv -qL 100
cat <<EOF | kubectl apply -n foo -f - # to limit HTTP requests to GET to /ip endpoint
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/ip"]
EOF
    sleep 10
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/ip\" -s -o /dev/null -H \"Authorization: Bearer \$TOKEN\" -w \"%{http_code}\\n\" # to verify request to /ip endpoint works" | pv -qL 100
    kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin:8000/ip" -s -o /dev/null -H "Authorization: Bearer $TOKEN" -w "%{http_code}\n" # to verify request to /ip endpoint works
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl exec \"\$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})\" -c sleep -n foo -- curl \"http://httpbin:8000/headers\" -s -o /dev/null -H \"Authorization: Bearer \$TOKEN\" -w \"%{http_code}\\n\" # to verify request to /headers endpoint is denied" | pv -qL 100
    kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin:8000/headers" -s -o /dev/null -H "Authorization: Bearer $TOKEN" -w "%{http_code}\n" # to verify request to /headers endpoint is denied
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl delete AuthorizationPolicy require-jwt -n foo # to delete policy"
    kubectl delete AuthorizationPolicy require-jwt -n foo
    echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to disables mutual TLS on port 80 only 
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin-authentication
  namespace: foo
spec:
  selector:
     matchLabels:
       app: httpbin
  portLevelMtls:
    80:
      mode: DISABLE
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to allow cluster.local/ns/default/sa/sleep service account and dev namespace to access workloads when requests have a valid JWT token
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: ALLOW
 rules:
 - from:
   - source:
       principals: [\"cluster.local/ns/default/sa/sleep\"]
   - source:
       namespaces: [\"dev\"]
   to:
   - operation:
       methods: [\"GET\"]
   when:
   - key: request.auth.claims[iss]
     values: [\"https://accounts.google.com\"]
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # to include a condition that request.headers[version] is either "v1" or "v2"
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin
 namespace: foo
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: ALLOW
 rules:
 - from:
   - source:
       principals: [\"cluster.local/ns/default/sa/sleep\"]
   to:
   - operation:
       methods: [\"GET\"]
   when:
   - key: request.headers[version]
     values: [\"v1\", \"v2\"]
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ cat <<EOF | kubectl apply -n foo -f - # to deny requests if the source is not the foo namespace
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: httpbin-deny
spec:
 selector:
   matchLabels:
     app: httpbin
     version: v1
 action: DENY
 rules:
 - from:
   - source:
       notNamespaces: [\"foo\"]
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # to allow "GET" and "HEAD" access to the workload
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-read
spec:
  selector:
    matchLabels:
      app: products
  action: ALLOW
  rules:
  - to:
    - operation:
         methods: [\"GET\", \"HEAD\"]
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # to allow access at paths with /test/* prefix or */info suffix
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tester
spec:
  selector:
    matchLabels:
      app: products
  action: ALLOW
  rules:
  - to:
    - operation:
        paths: [\"/test/*\", \"*/info\"]
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # to require a valid request principals, which is derived from JWT authentication, if the request path is not /healthz
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: disable-jwt-for-healthz
spec:
  selector:
    matchLabels:
      app: products
  action: ALLOW
  rules:
  - to:
    - operation:
        notPaths: [\"/healthz\"]
    from:
    - source:
        requestPrincipals: [\"*\"]
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # to deny request to /admin path for requests without request principals
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: enable-jwt-for-admin
spec:
  selector:
    matchLabels:
      app: products
  action: DENY
  rules:
  - to:
    - operation:
        paths: [\"/admin\"]
    from:
    - source:
        notRequestPrincipals: [\"*\"]
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # ALLOW policy that matches nothing. Start with allow-nothing policy and incrementally add ALLOW policies to open access to the workload
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
spec:
  action: ALLOW
  # the rules field is not specified, and the policy will never match.
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # DENY policy that explicitly denies all access. DENY policy takes precedence over the ALLOW policy. Useful to temporarily disable all access.
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
spec:
  action: DENY
  # the rules field has an empty rule, and the policy will always match.
  rules:
  - {}
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ cat <<EOF | kubectl apply -f - # ALLOW policy that allows full access to the workload. Useful to temporarily expose full access to the workload. Request could still be denied due to CUSTOM and DENY policies.
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-all
spec:
  action: ALLOW
  # This matches everything.
  rules:
  - {}
EOF" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'  
    echo && echo
    echo "$ kubectl delete namespace foo # to delete namespace" | pv -qL 100
    kubectl delete namespace foo
    echo
    echo "$ kubectl delete namespace bar # to delete namespace" | pv -qL 100
    kubectl delete namespace bar
    echo
    echo "$ kubectl delete namespace legacy # to delete namespace" | pv -qL 100
    kubectl delete namespace legacy
    echo
    echo "$ kubectl delete namespace $APPLICATION_NAMESPACE # to delete namespace" | pv -qL 100
    kubectl delete namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio-injection=enabled
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"        
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},8i"
    echo
    echo "1. Explore security" | pv -qL 100
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

