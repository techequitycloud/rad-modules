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
##############           Configure Cloud Run Service Mesh         ###############
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

mkdir -p `pwd`/gcp-cr-mesh > /dev/null 2>&1
export SCRIPTNAME=gcp-cr-mesh.sh
export PROJDIR=`pwd`/gcp-cr-mesh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION="us-central1"
export MESH_NAME="mesh"
export SERVICE_NAME="hello"
export SERVICE_IMAGE="us-docker.pkg.dev/cloudrun/container/hello:latest"
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
========================================================
Configure Cloud Run Service Mesh
--------------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Configure IAM Policies
 (3) Configure Service Mesh
 (4) Deploy Destination Service
 (5) Configure Destination Service Mesh Networking
 (6) Deploy Client Service in Service Mesh
 (7) Invoke Destination Service from Client Service
 (Q) Quit
--------------------------------------------------------
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
export GCP_REGION=$GCP_REGION
export MESH_NAME=$MESH_NAME
export SERVICE_NAME=$SERVICE_NAME
export SERVICE_IMAGE=$SERVICE_IMAGE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Mesh name is $MESH_NAME ***" | pv -qL 100
        echo "*** Service name is $SERVICE_NAME ***" | pv -qL 100
        echo "*** Service image is $SERVICE_IMAGE ***" | pv -qL 100
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
                    echo
                    echo "Enter the name of the virtual machine to analyze and migrate" | pv -qL 100
                    read MESH_NAME
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
export GCP_REGION=$GCP_REGION
export MESH_NAME=$MESH_NAME
export SERVICE_NAME=$SERVICE_NAME
export SERVICE_IMAGE=$SERVICE_IMAGE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Mesh name is $MESH_NAME ***" | pv -qL 100
                echo "*** Service name is $SERVICE_NAME ***" | pv -qL 100
                echo "*** Service image is $SERVICE_IMAGE ***" | pv -qL 100
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
gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable run.googleapis.com dns.googleapis.com networkservices.googleapis.com networksecurity.googleapis.com trafficdirector.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable run.googleapis.com dns.googleapis.com networkservices.googleapis.com networksecurity.googleapis.com trafficdirector.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable run.googleapis.com dns.googleapis.com networkservices.googleapis.com networksecurity.googleapis.com trafficdirector.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "$ gcloud --project $GCP_PROJECT services disable run.googleapis.com dns.googleapis.com networkservices.googleapis.com networksecurity.googleapis.com trafficdirector.googleapis.com # to disable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services disable run.googleapis.com dns.googleapis.com networkservices.googleapis.com networksecurity.googleapis.com trafficdirector.googleapis.com
else
    export STEP="${STEP},1i"
    echo
    echo "*** Enable APIs ***" | pv -qL 100
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
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/run.developer --no-user-output-enabled # to grant role" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/iam.serviceAccountUser --no-user-output-enabled # to grant role" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$(gcloud projects describe $GCP_PROJECT --format=\"value(projectNumber)\")-compute@developer.gserviceaccount.com --role=roles/trafficdirector.client --no-user-output-enabled # to grant role" | pv -qL 100    
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$(gcloud projects describe $GCP_PROJECT --format=\"value(projectNumber)\")-compute@developer.gserviceaccount.com --role=roles/cloudtrace.agent --no-user-output-enabled # to grant role" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:\$(gcloud projects describe $GCP_PROJECT --format=\"value(projectNumber)\")-compute@developer.gserviceaccount.com --role=roles/run.admin --no-user-output-enabled # to grant role" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/run.developer --no-user-output-enabled # to grant role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/run.developer  --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/iam.serviceAccountUser --no-user-output-enabled # to grant role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/iam.serviceAccountUser --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/trafficdirector.client --no-user-output-enabled # to grant role" | pv -qL 100    
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")-compute@developer.gserviceaccount.com --role=roles/trafficdirector.client --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/cloudtrace.agent --no-user-output-enabled # to grant role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")-compute@developer.gserviceaccount.com --role=roles/cloudtrace.agent --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/run.admin --no-user-output-enabled # to grant role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")-compute@developer.gserviceaccount.com --role=roles/run.admin --no-user-output-enabled
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1
    echo
    echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/run.developer --no-user-output-enabled # to delete role" | pv -qL 100
    gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/run.developer --no-user-output-enabled
    echo
    echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/iam.serviceAccountUser --no-user-output-enabled # to delete role" | pv -qL 100
    gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account 2>/dev/null) --role=roles/iam.serviceAccountUser --no-user-output-enabled
    echo
    echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/trafficdirector.client --no-user-output-enabled # to delete role" | pv -qL 100    
    gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/trafficdirector.client --no-user-output-enabled
    echo
    echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/cloudtrace.agent --no-user-output-enabled # to delete role" | pv -qL 100
    gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/cloudtrace.agent --no-user-output-enabled
    echo
    echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/run.admin --no-user-output-enabled # to delete role" | pv -qL 100
    gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/run.admin --no-user-output-enabled
else
    export STEP="${STEP},2i"   
    echo
    echo "*** Configure Policies ***" | pv -qL 100
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
    echo "$ echo \"name: $MESH_NAME\" > \$PROJDIR/mesh.yaml # to create mesh config file" | pv -qL 100
    echo
    echo "$ gcloud network-services meshes import \$MESH_NAME --source=\$PROJDIR/mesh.yaml --location=global # to configure mesh resource" | pv -qL 100
 elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1
    echo
    echo "$ echo \"name: $MESH_NAME\" > $PROJDIR/mesh.yaml # to create mesh config file" | pv -qL 100
    echo "name: $MESH_NAME" > $PROJDIR/mesh.yaml
    echo
    echo "$ gcloud network-services meshes import $MESH_NAME --source=$PROJDIR/mesh.yaml --location=global # to configure mesh resource" | pv -qL 100
    gcloud network-services meshes import $MESH_NAME --source=$PROJDIR/mesh.yaml --location=global
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "$ gcloud network-services meshes delete $MESH_NAME --location=global --quiet # to delete mesh resource" | pv -qL 100
    gcloud network-services meshes delete $MESH_NAME --location=global --quiet
else
    export STEP="${STEP},3i"        
    echo
    echo "** Configure Mesh Resource ***" | pv -qL 100
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
    echo "$ gcloud run deploy \$SERVICE_NAME --no-allow-unauthenticated --region=\$GCP_REGION --image=\$SERVICE_IMAGE # to deploy service" | pv -qL 100
    echo
    echo "$ gcloud run services add-iam-policy-binding \$SERVICE_NAME --region \$GCP_REGION --member=serviceAccount:\$(gcloud projects describe \$GCP_PROJECT --format=\"value(projectNumber)\")-compute@developer.gserviceaccount.com --role=roles/run.invoker --no-user-output-enabled # to grant role" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1
    echo
    echo "$ gcloud run deploy $SERVICE_NAME --no-allow-unauthenticated --region=$GCP_REGION --image=$SERVICE_IMAGE # to deploy service" | pv -qL 100
    gcloud run deploy $SERVICE_NAME --no-allow-unauthenticated --region=$GCP_REGION --image=$SERVICE_IMAGE
    echo
    echo "$ gcloud run services add-iam-policy-binding $SERVICE_NAME --region $GCP_REGION --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/run.invoker --no-user-output-enabled # to grant role" | pv -qL 100
    gcloud run services add-iam-policy-binding $SERVICE_NAME --region $GCP_REGION --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")-compute@developer.gserviceaccount.com --role=roles/run.invoker --no-user-output-enabled
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"   
    echo
    echo "$ gcloud run services remove-iam-policy-binding $SERVICE_NAME --region=$GCP_REGION --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)')-compute@developer.gserviceaccount.com --role=roles/run.invoker --no-user-output-enabled # to delete policy" | pv -qL 100
    gcloud run services remove-iam-policy-binding $SERVICE_NAME --region=$GCP_REGION --member=serviceAccount:$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")-compute@developer.gserviceaccount.com --role=roles/run.invoker --no-user-output-enabled
    echo
    echo "$ gcloud --project $GCP_PROJECT run services delete ${SERVICE_NAME} --region $GCP_REGION # to delete service" | pv -qL 100
    gcloud run services delete ${SERVICE_NAME} --region=$GCP_REGION --quiet
else
    export STEP="${STEP},4i"   
    echo
    echo "*** Deploy destination service ***" | pv -qL 100
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
    echo "$ gcloud compute network-endpoint-groups create \${SERVICE_NAME}-neg --region=\$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=\$SERVICE_NAME # to configure NEG" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create \${SERVICE_NAME}-\${GCP_REGION} --global --load-balancing-scheme=INTERNAL_SELF_MANAGED # to create backend service" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend \${SERVICE_NAME}-\${GCP_REGION} --global --network-endpoint-group=\${SERVICE_NAME}-neg --network-endpoint-group-region=\$GCP_REGION # to add serverless backend to backend service" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/http_route.yaml
name: \"\$SERVICE_NAME-route\"
hostnames:
- \"\$SERVICE_NAME-\$(gcloud projects describe \$GCP_PROJECT --format='value(projectNumber)').\$GCP_REGION.run.app\"
meshes:
- \"projects/\$GCP_PROJECT/locations/global/meshes/\$MESH_NAME\"
rules:
- action:
   destinations:
   - serviceName: \"projects/\$GCP_PROJECT/locations/global/backendServices/\${SERVICE_NAME}-\${GCP_REGION}\"
EOF # to create the HTTPRoute specification" | pv -qL 100
    echo
    echo "$ gcloud network-services http-routes import \${SERVICE_NAME}-route --source=\$PROJDIR/http_route.yaml --location=global # to create HTTPRoute resource" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1
    echo
    echo "$ gcloud compute network-endpoint-groups create ${SERVICE_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=$SERVICE_NAME # to configure NEG" | pv -qL 100
    gcloud compute network-endpoint-groups create ${SERVICE_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=$SERVICE_NAME
    echo
    echo "$ gcloud compute backend-services create ${SERVICE_NAME}-${GCP_REGION} --global --load-balancing-scheme=INTERNAL_SELF_MANAGED # to create backend service" | pv -qL 100
    gcloud compute backend-services create ${SERVICE_NAME}-${GCP_REGION} --global --load-balancing-scheme=INTERNAL_SELF_MANAGED
    echo
    echo "$ gcloud compute backend-services add-backend ${SERVICE_NAME}-${GCP_REGION} --global --network-endpoint-group=${SERVICE_NAME}-neg --network-endpoint-group-region=$GCP_REGION # to add serverless backend to backend service" | pv -qL 100
    gcloud compute backend-services add-backend ${SERVICE_NAME}-${GCP_REGION} --global --network-endpoint-group=${SERVICE_NAME}-neg --network-endpoint-group-region=$GCP_REGION
    echo
    echo "$ cat <<EOF > $PROJDIR/http_route.yaml
name: "$SERVICE_NAME-route"
hostnames:
- "$SERVICE_NAME-$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)').$GCP_REGION.run.app"
meshes:
- "projects/$GCP_PROJECT/locations/global/meshes/$MESH_NAME"
rules:
- action:
   destinations:
   - serviceName: "projects/$GCP_PROJECT/locations/global/backendServices/${SERVICE_NAME}-${GCP_REGION}"
EOF # to create the HTTPRoute specification" | pv -qL 100
    cat <<EOF > $PROJDIR/http_route.yaml
name: "$SERVICE_NAME-route"
hostnames:
- "$SERVICE_NAME-$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)').$GCP_REGION.run.app"
meshes:
- "projects/$GCP_PROJECT/locations/global/meshes/$MESH_NAME"
rules:
- action:
   destinations:
   - serviceName: "projects/$GCP_PROJECT/locations/global/backendServices/${SERVICE_NAME}-${GCP_REGION}"
EOF
    echo
    echo "$ gcloud network-services http-routes import ${SERVICE_NAME}-route --source=$PROJDIR/http_route.yaml --location=global # to create HTTPRoute resource" | pv -qL 100
    gcloud network-services http-routes import ${SERVICE_NAME}-route --source=$PROJDIR/http_route.yaml --location=global
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"   
    echo
    echo "$ gcloud network-services http-routes delete ${SERVICE_NAME}-route --location=global --quiet # to delete HTTP Route" | pv -qL 100
    gcloud network-services http-routes delete ${SERVICE_NAME}-route --location=global --quiet
    echo
    echo "$ gcloud compute backend-services remove-backend ${SERVICE_NAME}-${GCP_REGION} --global --network-endpoint-group=${SERVICE_NAME}-neg --network-endpoint-group-region=$GCP_REGION --quiet # to delete Backend from the Backend Service" | pv -qL 100
    gcloud compute backend-services remove-backend ${SERVICE_NAME}-${GCP_REGION} --global --network-endpoint-group=${SERVICE_NAME}-neg --network-endpoint-group-region=$GCP_REGION --quiet
    echo
    echo "$ gcloud compute backend-services delete ${SERVICE_NAME}-${GCP_REGION} --global --quiet # to delete Backend from the Backend Service" | pv -qL 100
    gcloud compute backend-services delete ${SERVICE_NAME}-${GCP_REGION} --global --quiet
    echo
    echo "$ gcloud compute network-endpoint-groups delete ${SERVICE_NAME}-neg --region=$GCP_REGION --quiet # to delete Network Endpoint Group" | pv -qL 100
    gcloud compute network-endpoint-groups delete ${SERVICE_NAME}-neg --region=$GCP_REGION --quiet
else
    echo "*** Configure destination service mesh networking ***" | pv -qL 100
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
    echo "$ gcloud beta run deploy fortio --region=\$GCP_REGION --image=fortio/fortio --network=default --subnet=default --mesh=\"projects/\$GCP_PROJECT/locations/global/meshes/\$MESH_NAME\" --quiet # to deploy service" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1
    echo
    echo "$ gcloud beta run deploy fortio --region=$GCP_REGION --image=fortio/fortio --network=default --subnet=default --mesh="projects/$GCP_PROJECT/locations/global/meshes/$MESH_NAME" --quiet # to deploy service" | pv -qL 100
    gcloud beta run deploy fortio --region=$GCP_REGION --image=fortio/fortio --network=default --subnet=default --mesh="projects/$GCP_PROJECT/locations/global/meshes/$MESH_NAME" --quiet
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"   
    echo
    echo "$ gcloud beta run services delete fortio --region=$GCP_REGION --quiet # to delete service" | pv -qL 100
    gcloud beta run services delete fortio --region=$GCP_REGION --quiet
else
    export STEP="${STEP},6i"   
    echo
    echo "***  Deploy fortio service used to forwarding traffic to HTTP routes***" | pv -qL 100
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
    echo "$ TEST_SERVICE_URL=\$(gcloud run services describe \$SERVICE_NAME --region=\$GCP_REGION --format='value(status.url)' --project=\$GCP_PROJECT) # to get URL" | pv -qL 100
    echo
    echo "$ curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" \"\$TEST_SERVICE_URL/fortio/fetch/\$SERVICE_NAME-\$(gcloud projects describe \$GCP_PROJECT --format='value(projectNumber)').\$GCP_REGION.run.app\" # to invoke service" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/region $GCP_REGION > /dev/null 2>&1
    echo
    echo "$ TEST_SERVICE_URL=\$(gcloud run services describe $SERVICE_NAME --region=$GCP_REGION --format='value(status.url)' --project=$GCP_PROJECT) # to get URL" | pv -qL 100
    TEST_SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$GCP_REGION --format='value(status.url)' --project=$GCP_PROJECT)
    echo
    echo "$ curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" \"$TEST_SERVICE_URL/fortio/fetch/$SERVICE_NAME-$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)').$GCP_REGION.run.app\" # to invoke service" | pv -qL 100
    curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$TEST_SERVICE_URL/fortio/fetch/$SERVICE_NAME-$(gcloud projects describe $GCP_PROJECT --format='value(projectNumber)').$GCP_REGION.run.app"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"   
    echo
    echo "*** Nothing to Delete ***" | pv -qL 100
else
    export STEP="${STEP},7i"   
    echo
    echo "*** Invoke service from a mesh client ***" | pv -qL 100
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
