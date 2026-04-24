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
##############        Migrate Virtual Machine to Container        ###############
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

mkdir -p `pwd`/gcp-m2c-vm > /dev/null 2>&1
export SCRIPTNAME=gcp-m2c-vm.sh
export PROJDIR=`pwd`/gcp-m2c-vm

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export VM_NAME=NOT_SET
export CONTAINER_NAME=NOT_SET
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
===============================================
Configure Migrate to Containers
-----------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Analyze virtual machine 
 (3) Generate Migrate to Containers artefacts 
 (4) Migrate virtual machine to container
 (Q) Quit
-----------------------------------------------
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
            echo
            echo "*** Create a VM to migrate using the Google Marketplace and enter the name below ***" | pv -qL 100
            echo
            echo "Enter the name of the virtual machine to analyze and migrate" | pv -qL 100
            read VM_NAME
            echo
            echo "Enter the name of the container machine to generate (ensure this corresponds to the log file location)" | pv -qL 100
            read CONTAINER_NAME
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
export VM_NAME=$VM_NAME
export CONTAINER_NAME=$CONTAINER_NAME
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Virtual machine name is $VM_NAME ***" | pv -qL 100
        echo "*** Container name is $CONTAINER_NAME ***" | pv -qL 100
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
                    read VM_NAME
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
export VM_NAME=$VM_NAME
export CONTAINER_NAME=$CONTAINER_NAME
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Virtual machine name is $VM_NAME ***" | pv -qL 100
                echo "*** Container name is $CONTAINER_NAME ***" | pv -qL 100
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
    echo "$ gcloud --project \$GCP_PROJECT services enable servicemanagement.googleapis.com servicecontrol.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com container.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com containeranalysis.googleapis.com run.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable servicemanagement.googleapis.com servicecontrol.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com container.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com containeranalysis.googleapis.com run.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable servicemanagement.googleapis.com servicecontrol.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com container.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com clouddeploy.googleapis.com containeranalysis.googleapis.com run.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
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
    echo "$ gcloud --project \$GCP_PROJECT compute instances start \${VM_NAME} --zone \$VM_ZONE # to start instance" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh \$VM_NAME --zone \$VM_ZONE --command=\"ps aux | grep mysql\" # to check for database process" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh \$VM_NAME --zone \$VM_ZONE  --command=\"rm -rf mcdc-linux-collect.sh && wget https://mcdc-release.storage.googleapis.com/\$(curl -s https://mcdc-release.storage.googleapis.com/latest)/mcdc-linux-collect.sh && chmod +x mcdc-linux-collect.sh\" # to download the collection script to the VM and make it executable (--tunnel-through-iap)" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh \$VM_NAME --zone \$VM_ZONE  --command=\"rm -rf mcdc && wget https://mcdc-release.storage.googleapis.com/\$(curl -s https://mcdc-release.storage.googleapis.com/latest)/mcdc && chmod +x mcdc\" # to download the analysis tool to the VM and make it executable" | pv -qL 100
    echo
    echo "$ cat <<EOF>> \$PROJDIR/analyzevm.sh
#!/bin/bash
rm -rf analysis-report-*
rm -rf mcdc-collect-*.tar
sudo ./mcdc-linux-collect.sh
sudo ./mcdc discover import \$(find -type f -name mcdc-collect-*.tar)
sudo ./mcdc report --format json > \${VM_NAME}-mcdc-report.json
sudo ./mcdc report --full --format html> \${VM_NAME}-mcdc-report.html
EOF" | pv -qL 100
    echo
    echo "$ gcloud compute --quiet --project \$GCP_PROJECT scp --zone \$VM_ZONE \$PROJDIR/analyzevm.sh \$VM_NAME:./analyzevm.sh # to copy script to VM" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT ssh \$VM_NAME --zone \$VM_ZONE --command=\"chmod +x ./analyzevm.sh; ./analyzevm.sh\" # to analyze VM" | pv -qL 100
    echo
    echo "$ gcloud compute --quiet --project \$GCP_PROJECT scp --zone \$VM_ZONE \$VM_NAME:./\${VM_NAME}-mcdc-report.json \$PROJDIR # to copy report" | pv -qL 100
    echo
    echo "$ gcloud compute --quiet --project \$GCP_PROJECT scp --zone \$VM_ZONE \$VM_NAME:./\${VM_NAME}-mcdc-report.html \$PROJDIR # to copy report" | pv -qL 100
    echo
    echo "$ cloudshell download \${PROJDIR}/\${VM_NAME}-mcdc-report.json # to download report" | pv -qL 100
    echo
    echo "$ cloudshell download \${PROJDIR}/\${VM_NAME}-mcdc-report.html # to download report" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    echo
    export VM_ZONE=$(gcloud compute instances list --project=$GCP_PROJECT --filter=name:$VM_NAME --format="table[csv,no-heading](zone)")
    echo "$ gcloud --project $GCP_PROJECT compute instances start ${VM_NAME} --zone $VM_ZONE # to start instance" | pv -qL 100
    gcloud --project $GCP_PROJECT compute instances start ${VM_NAME} --zone $VM_ZONE
    sleep 15
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command=\"ps aux | grep mysql\" # to check for database process" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command="ps aux | grep mysql"
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command=\"rm -rf mcdc-linux-collect.sh && wget https://mcdc-release.storage.googleapis.com/$(curl -s https://mcdc-release.storage.googleapis.com/latest)/mcdc-linux-collect.sh && chmod +x mcdc-linux-collect.sh\" # to download the collection script to the VM and make it executable (--tunnel-through-iap)" | pv -qL 100    
    gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command="rm -rf mcdc-linux-collect.sh && wget https://mcdc-release.storage.googleapis.com/$(curl -s https://mcdc-release.storage.googleapis.com/latest)/mcdc-linux-collect.sh > /dev/null 2>&1 && chmod +x mcdc-linux-collect.sh"
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command=\"rm -rf mcdc && wget https://mcdc-release.storage.googleapis.com/\$(curl -s https://mcdc-release.storage.googleapis.com/latest)/mcdc && chmod +x mcdc\" # to download the analysis tool to the VM and make it executable" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command="rm -rf mcdc && wget https://mcdc-release.storage.googleapis.com/$(curl -s https://mcdc-release.storage.googleapis.com/latest)/mcdc > /dev/null 2>&1 && chmod +x mcdc"
    curl -O "https://mcdc-release.storage.googleapis.com/$(curl -s https://mcdc-release.storage.googleapis.com/latest)/mcdc"
chmod +x mcdc
    echo
    rm -rf $PROJDIR/analyzevm.sh
    echo "$ cat <<EOF>> $PROJDIR/analyzevm.sh
#!/bin/bash
rm -rf analysis-report-*
rm -rf mcdc-collect-*.tar
sudo ./mcdc-linux-collect.sh
sudo ./mcdc discover import \$(find -type f -name mcdc-collect-*.tar)
sudo ./mcdc report --format json > ${VM_NAME}-mcdc-report.json
sudo ./mcdc report --full --format html> ${VM_NAME}-mcdc-report.html
EOF" | pv -qL 100
cat <<EOF>> $PROJDIR/analyzevm.sh
#!/bin/bash
rm -rf analysis-report-*
rm -rf mcdc-collect-*.tar
sudo ./mcdc-linux-collect.sh
sleep 10
sudo ./mcdc discover import \$(find -type f -name mcdc-collect-*.tar)
sudo ./mcdc report --format json > ${VM_NAME}-mcdc-report.json
sudo ./mcdc report --full --format html> ${VM_NAME}-mcdc-report.html
EOF
    sleep 30
    echo
    echo "$ gcloud compute --quiet --project $GCP_PROJECT scp --zone $VM_ZONE $PROJDIR/analyzevm.sh $VM_NAME:./analyzevm.sh # to copy script to VM" | pv -qL 100
    gcloud compute --quiet --project $GCP_PROJECT scp --zone $VM_ZONE $PROJDIR/analyzevm.sh $VM_NAME:./analyzevm.sh
    echo
    echo "$ gcloud compute --project $GCP_PROJECT ssh $VM_NAME --zone $VM_ZONE --command=\"chmod +x ./analyzevm.sh; ./analyzevm.sh\" # to analyze VM" | pv -qL 100
    gcloud compute --project $GCP_PROJECT ssh $VM_NAME --zone $VM_ZONE --command="chmod +x ./analyzevm.sh; ./analyzevm.sh"
    echo
    echo "$ gcloud compute --quiet --project $GCP_PROJECT scp --zone $VM_ZONE $VM_NAME:./${VM_NAME}-mcdc-report.json $PROJDIR # to copy report" | pv -qL 100
    gcloud compute --quiet --project $GCP_PROJECT scp --zone $VM_ZONE $VM_NAME:./${VM_NAME}-mcdc-report.json $PROJDIR
    echo
    echo "$ gcloud compute --quiet --project $GCP_PROJECT scp --zone $VM_ZONE $VM_NAME:./${VM_NAME}-mcdc-report.html $PROJDIR # to copy report" | pv -qL 100
    gcloud compute --quiet --project $GCP_PROJECT scp --zone $VM_ZONE $VM_NAME:./${VM_NAME}-mcdc-report.html $PROJDIR
    echo
    echo "$ cloudshell download ${PROJDIR}/${VM_NAME}-mcdc-report.json # to download report" | pv -qL 100
    cloudshell download ${PROJDIR}/${VM_NAME}-mcdc-report.json
    echo
    echo "$ cloudshell download ${PROJDIR}/${VM_NAME}-mcdc-report.html # to download report" | pv -qL 100
    cloudshell download ${PROJDIR}/${VM_NAME}-mcdc-report.html
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    export VM_ZONE=$(gcloud compute instances list --project=$GCP_PROJECT --filter=name:$VM_NAME --format="table[csv,no-heading](zone)")
    echo "$ gcloud --project $GCP_PROJECT compute instances delete ${VM_NAME} --zone $VM_ZONE # to delete instance" | pv -qL 100
    gcloud --project $GCP_PROJECT compute instances delete ${VM_NAME} --zone $VM_ZONE
else
    export STEP="${STEP},2i"   
    echo
    echo "1. Start instance" | pv -qL 100
    echo "2. Check for database process" | pv -qL 100
    echo "3. Download collection script" | pv -qL 100
    echo "4. Download analysis tool" | pv -qL 100
    echo "5. Analyze VM" | pv -qL 100
    echo "6. Generate report" | pv -qL 100
    echo "7. Download report" | pv -qL 100
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
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh \$VM_NAME --zone \$VM_ZONE  --command=\"sudo apt install rsync\" # to install rsync in virtual machine" | pv -qL 100
    echo
    echo "$ curl -O \"https://m2c-cli-release.storage.googleapis.com/\$(curl -s https://m2c-cli-release.storage.googleapis.com/latest)/linux/amd64/m2c\" && chmod +x ./m2c # to download or upgrade the Migrate to Containers CLI" | pv -qL 100
    echo
    echo "$ curl -O https://storage.googleapis.com/modernize-plugins-prod/\$(curl -s https://storage.googleapis.com/modernize-plugins-prod/latest)/m2c-offline-bundle-linux.tar # to download the offline Migrate to Containers CLI plugins bundle" | pv -qL 100
    echo
    echo "$ \$PROJDIR/m2c plugins unpack -i \$PROJDIR/m2c-offline-bundle-linux.tar && rm \$PROJDIR/m2c-offline-bundle-linux.tar # to Unpack the offline Migrate to Containers CLI plugins bundle" | pv -qL 100
    # echo
    # echo "$ \$PROJDIR/m2c copy default-filters > \$PROJDIR/filters.txt # to export directory filters" | pv -qL 100
    # echo
    # echo "$ mkdir \$PROJDIR/filesystem && \$PROJDIR/m2c copy gcloud -p \$GCP_PROJECT -z \$VM_ZONE -n \$VM_NAME -o \$PROJDIR/filesystem --filters \$PROJDIR/filters.txt # to create local copy of source machine file system" | pv -qL 100
    echo
    echo "$ sudo apt-get update -qq && sudo apt-get install -y rsync # Install rsync" | pv -qL 100
    sudo apt-get update -qq && sudo apt-get install -y rsync
    echo
    echo "$ rsync -avzh --progress --stats --exclude-from=$PROJDIR/filters.txt --rsync-path="sudo rsync" -e "gcloud compute ssh \$VM_NAME --zone=\$VM_ZONE --" :/ $PROJDIR/filesystem/ # to syncronise file system" | pv -qL 100
    echo
    echo "$ mkdir \$PROJDIR/migrationplan && \$PROJDIR/m2c analyze -s \$PROJDIR/filesystem  -p linux-vm-container -o \$PROJDIR/migrationplan  # to get and update migration plan" | pv -qL 100
    echo
    echo "$ gcloud compute --project \$GCP_PROJECT --quiet ssh \$VM_NAME --zone \$VM_ZONE  --command=\"sudo netstat --programs --listening --tcp --udp\" # to retrieve the endpoints ports by checking program listening ports" | pv -qL 100
    echo
    echo "$ mkdir \$PROJDIR/artifacts && \$PROJDIR/m2c generate -i \$PROJDIR/migrationplan -o \$PROJDIR/artifacts # to generate migration artifacts" | pv -qL 100

 elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    kubectx processing > /dev/null 2>&1
    echo
    export VM_ZONE=$(gcloud compute instances list --project=$GCP_PROJECT --filter=name:$VM_NAME --format="table[csv,no-heading](zone)")
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command=\"sudo apt install rsync\" # to install rsync in virtual machine" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command="sudo apt install rsync"
    echo
    echo "$ cd $PROJDIR # to change to working directory" | pv -qL 100
    cd $PROJDIR
    echo
    echo "$ curl -O \"https://m2c-cli-release.storage.googleapis.com/\$(curl -s https://m2c-cli-release.storage.googleapis.com/latest)/linux/amd64/m2c\" && chmod +x ./m2c # to download or upgrade the Migrate to Containers CLI" | pv -qL 100
    curl -O "https://m2c-cli-release.storage.googleapis.com/$(curl -s https://m2c-cli-release.storage.googleapis.com/latest)/linux/amd64/m2c" && chmod +x ./m2c 
    echo
    echo "$ curl -O https://storage.googleapis.com/modernize-plugins-prod/\$(curl -s https://storage.googleapis.com/modernize-plugins-prod/latest)/m2c-offline-bundle-linux.tar # to download the offline Migrate to Containers CLI plugins bundle" | pv -qL 100
    curl -O https://storage.googleapis.com/modernize-plugins-prod/$(curl -s https://storage.googleapis.com/modernize-plugins-prod/latest)/m2c-offline-bundle-linux.tar
    echo
    echo "$ $PROJDIR/m2c plugins unpack -i $PROJDIR/m2c-offline-bundle-linux.tar && rm $PROJDIR/m2c-offline-bundle-linux.tar # to Unpack the offline Migrate to Containers CLI plugins bundle" | pv -qL 100
    $PROJDIR/m2c plugins unpack -i $PROJDIR/m2c-offline-bundle-linux.tar && rm $PROJDIR/m2c-offline-bundle-linux.tar 
    echo
    echo "$ $PROJDIR/m2c copy default-filters > $PROJDIR/filters.txt # to export directory filters" | pv -qL 100
    $PROJDIR/m2c copy default-filters > $PROJDIR/filters.txt
    echo
    read -n 1 -s -r -p "*** Review and update $PROJDIR/filters.txt to reduce the size of copied file system ***" | pv -qL 100
    echo && echo
    sudo rm -rf $PROJDIR/filesystem
    # echo "$ mkdir $PROJDIR/filesystem && $PROJDIR/m2c copy gcloud -p $GCP_PROJECT -z $VM_ZONE -n $VM_NAME -o $PROJDIR/filesystem --filters $PROJDIR/filters.txt # to create local copy of source machine file system" | pv -qL 100
    # mkdir $PROJDIR/filesystem && $PROJDIR/m2c copy gcloud -p $GCP_PROJECT -z $VM_ZONE -n $VM_NAME -o $PROJDIR/filesystem --filters $PROJDIR/filters.txt
    echo
    echo "$ sudo apt-get update -qq && sudo apt-get install -y rsync # Install rsync" | pv -qL 100
    sudo apt-get update -qq && sudo apt-get install -y rsync
    echo
    echo "$ rsync -avzh --progress --stats --exclude-from=$PROJDIR/filters.txt --rsync-path="sudo rsync" -e "gcloud compute ssh $VM_NAME --zone=$VM_ZONE --" :/ $PROJDIR/filesystem/ # to syncronise file system" | pv -qL 100
    rsync -avzh --progress --stats --exclude-from=$PROJDIR/filters.txt --rsync-path="sudo rsync" -e "gcloud compute ssh $VM_NAME --zone=$VM_ZONE --" :/ $PROJDIR/filesystem/
    echo
    sudo rm -rf $PROJDIR/migrationplan
    echo "$ mkdir $PROJDIR/migrationplan && $PROJDIR/m2c analyze -s $PROJDIR/filesystem  -p linux-vm-container -o $PROJDIR/migrationplan  # to get and update migration plan" | pv -qL 100
    mkdir $PROJDIR/migrationplan && $PROJDIR/m2c analyze -s $PROJDIR/filesystem  -p linux-vm-container -o $PROJDIR/migrationplan
    echo
    echo "$ gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command=\"sudo netstat --programs --listening --tcp --udp\" # to retrieve the endpoints ports by checking program listening ports" | pv -qL 100
    gcloud compute --project $GCP_PROJECT --quiet ssh $VM_NAME --zone $VM_ZONE  --command="sudo netstat --programs --listening --tcp --udp"
    echo
    read -s -r -p $'*** Update the migration plan $PROJDIR/migrationplan/config.yaml and Enter any key to continue ***' | pv -qL 100
    echo && echo
    sudo rm -rf $PROJDIR/artifacts
    echo "$ mkdir $PROJDIR/artifacts && $PROJDIR/m2c generate -i $PROJDIR/migrationplan -o $PROJDIR/artifacts # to generate migration artifacts" | pv -qL 100
    mkdir $PROJDIR/artifacts && $PROJDIR/m2c generate -i $PROJDIR/migrationplan -o $PROJDIR/artifacts
    echo
    echo "$ sudo rm -rf $PROJDIR/filesystem # to delete the filesystem" | pv -qL 100
    sudo rm -rf $PROJDIR/filesystem
    stty echo # to ensure input characters are echoed on terminal
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "*** Not Implemented ***" | pv -qL 100
else
    export STEP="${STEP},3i"        
    echo
    echo "1. Create migration plan" | pv -qL 100
    echo "2. Generate artifacts" | pv -qL 100
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
    echo "$ sed -i \"/^ENTRYPOINT/i \$LINE\" \"\$FILE\" # to customize Dockerfile" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/artifacts/skaffold_gke.yaml
apiVersion: skaffold/v4beta4
kind: Config
build:
  artifacts:
    - image: \${CONTAINER_NAME}
      context: ./
      docker:
        dockerfile: Dockerfile
  googleCloudBuild:
    projectId: qwiklabs-gcp-01-cc6a6951f7f9
    timeout: 3600s
    logStreamingOption: STREAM_OFF
manifests:
  rawYaml:
    - ./deployment_cloudrun.yaml
deploy:
  cloudrun: {}
EOF" | pv -qL 100
    echo
    echo "$ cp \$PROJDIR/artifacts/skaffold_gke.yaml \$PROJDIR/artifacts/skaffold.yaml # to create config file" | pv -qL 100
    echo
    echo "$ cat <<EOF > \$PROJDIR/artifacts/deployment_cloudrun.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: \${CONTAINER_NAME}
  labels:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
    spec:
      containers:
      - image: \${CONTAINER_NAME}
        env:
          - name: HC_V2K_SERVICE_MANAGER
            value: \"true\"
        ports:
          - containerPort: 80
EOF" | pv -qL 100
    echo
    echo "$ skaffold run -d eu.gcr.io/\$GCP_PROJECT --cloud-run-location=\$GCP_REGION --cloud-run-project=\$GCP_PROJECT # to deploy the workload" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    export VM_ZONE=$(gcloud compute instances list --project=$GCP_PROJECT --filter=name:$VM_NAME --format="table[csv,no-heading](zone)")
    export GCP_REGION=$(gcloud compute instances list --project=$GCP_PROJECT --filter=name:$VM_NAME --format="table[csv,no-heading](zone)" | awk -F'-' '{print $1"-"$2}')
    cd $PROJDIR/artifacts
    LINE="RUN mkdir -p /var/log/${CONTAINER_NAME}/ && chmod -R 744 /var/log/${CONTAINER_NAME}/"
    FILE="$PROJDIR/artifacts/Dockerfile"
    echo
    echo "$ sed -i \"/^ENTRYPOINT/i $LINE\" \"$FILE\" # to customize Dockerfile" | pv -qL 100
    sed -i "/^ENTRYPOINT/i $LINE" "$FILE"
    echo
    echo "$ cat <<EOF > $PROJDIR/artifacts/skaffold_cloudrun.yaml
apiVersion: skaffold/v4beta4
kind: Config
build:
  artifacts:
    - image: ${CONTAINER_NAME}
      context: ./
      docker:
        dockerfile: Dockerfile
  googleCloudBuild:
    projectId: $GCP_PROJECT
    timeout: 3600s
    logStreamingOption: STREAM_OFF
manifests:
  rawYaml:
    - ./deployment_cloudrun.yaml
deploy:
  cloudrun: {}
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/artifacts/skaffold_cloudrun.yaml
apiVersion: skaffold/v4beta4
kind: Config
build:
  artifacts:
    - image: ${CONTAINER_NAME}
      context: ./
      docker:
        dockerfile: Dockerfile
  googleCloudBuild:
    projectId: $GCP_PROJECT
    timeout: 3600s
    logStreamingOption: STREAM_OFF
manifests:
  rawYaml:
    - ./deployment_cloudrun.yaml
deploy:
  cloudrun: {}
EOF
    echo
    echo "$ cat <<EOF > $PROJDIR/artifacts/deployment_cloudrun.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${CONTAINER_NAME}
  labels:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
    spec:
      containers:
      - image: ${CONTAINER_NAME}
        env:
          - name: HC_V2K_SERVICE_MANAGER
            value: \"true\"
        ports:
          - containerPort: 80
EOF" | pv -qL 100
    cat <<EOF > $PROJDIR/artifacts/deployment_cloudrun.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${CONTAINER_NAME}
  labels:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
    spec:
      containers:
      - image: ${CONTAINER_NAME}
        env:
          - name: HC_V2K_SERVICE_MANAGER
            value: "true"
        ports:
          - containerPort: 80
EOF
    echo
    echo "$ skaffold run -f $PROJDIR/artifacts/skaffold_cloudrun.yaml -d eu.gcr.io/$GCP_PROJECT --cloud-run-location=$GCP_REGION --cloud-run-project=$GCP_PROJECT # to deploy the workload to Cloud Run" | pv -qL 100
    skaffold run -f $PROJDIR/artifacts/skaffold_cloudrun.yaml -d eu.gcr.io/$GCP_PROJECT --cloud-run-location=$GCP_REGION --cloud-run-project=$GCP_PROJECT
    echo
    echo "$ skaffold run -f $PROJDIR/artifacts/skaffold.yaml -d eu.gcr.io/$GCP_PROJECT # to deploy the workload to GKE" | pv -qL 100
    skaffold run -f $PROJDIR/artifacts/skaffold.yaml -d eu.gcr.io/$GCP_PROJECT
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"   
    echo
    echo "$ gcloud --project $GCP_PROJECT run services delete ${CONTAINER_NAME} --region $GCP_REGION # to delete service" | pv -qL 100
    gcloud --project $GCP_PROJECT run services delete ${CONTAINER_NAME} --region $GCP_REGION
    echo
    echo "$ kubectl delete -f $PROJDIR/artifacts/deployment_spec.yaml # to delete service" | pv -qL 100
    kubectl delete -f $PROJDIR/artifacts/deployment_spec.yaml
else
    export STEP="${STEP},4i"   
    echo
    echo "1. Get the generated YAML artifacts" | pv -qL 100
    echo "2. Apply deployment spec yaml" | pv -qL 100
    echo "3. Apply service spec yaml" | pv -qL 100
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
