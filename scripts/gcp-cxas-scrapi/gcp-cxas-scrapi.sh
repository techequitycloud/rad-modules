#!/bin/bash
#
# Copyright 2026 Google LLC
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
##################       CXAS SCRAPI Cymbal Pools Demo         ################
#################################################################################
#
# CXAS SCRAPI (github.com/GoogleCloudPlatform/cxas-scrapi) is a Python library
# and `cxas` CLI that wraps CX Agent Studio (console at ces.cloud.google.com),
# Google's instruction/LLM-driven successor to flow-based Dialogflow CX. Most
# steps below are real `cxas`/`gcloud` calls -- this is a genuine pip package
# with a stable CLI, unlike console-only products covered by other scripts in
# this directory. A handful of commands (callback scaffolding in step 6,
# `cxas branch` in step 12, sub-agent routing in step 13, `cxas trace`/
# `cxas insights` in steps 20-21) are inferred from the documentation site and
# the project layout described in Google's own hands-on labs rather than
# verified against a live project -- each is flagged inline with the exact
# command to fall back to (`cxas local create --help`, etc.) if the call
# fails, so treat this script as a strong starting point and rerun it against
# a real project before using it live in front of a class. Steps 14-16 and 18
# hand control to the interactive Antigravity CLI (`agy`) for "vibe coding" --
# the script prints the exact natural-language prompt to paste in, then pauses
# for you to complete the conversation and exit back to the script.

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=1 # $(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=1 # $(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)

echo
echo
echo -e "                        👋  Welcome to Cloud Demo! 💻"
echo
echo -e "                          Developed by: Shiyghan Navti"
echo -e "          Need help? Contact shiyghan.navti@techequity.cloud for assistance"
echo
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv ffmpeg > /dev/null 2>&1
echo
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-cxas-scrapi > /dev/null 2>&1
export SCRIPTNAME=gcp-cxas-scrapi.sh
export PROJDIR=`pwd`/gcp-cxas-scrapi

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export CXAS_LOCATION=us
export GCS_BUCKET=${GCP_PROJECT}-cxas
export APP_NAME="Cymbal Pools Service"
export APP_ID=cymbal-pools-service
export APP_DIR=Cymbal_Pools_Service
export MODEL=gemini-3-flash
export AGENT_NAME=scheduler
export FAQ_AGENT_NAME=faq
export GUARDRAIL_NAME=no_payment_info
export BRANCH_APP_NAME="Cymbal Pools Service Branch"
export BRANCH_APP_ID=NOT_SET
export BRANCH_APP_DIR=Cymbal_Pools_Service_Branch
export FOUNDRY_APP_NAME="Cymbal Pools Membership"
export FOUNDRY_APP_ID=cymbal-pools-membership
export FOUNDRY_APP_DIR=Cymbal_Pools_Membership
export VOICE_APP_NAME="Cymbal Pools Service Voice"
export VOICE_APP_ID=cymbal-pools-service-voice
export VOICE_APP_DIR=Cymbal_Pools_Service_Voice
export VOICE_MODEL=gemini-3.1-flash-live
export IAM_PRINCIPAL=NOT_SET
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
==============================================================
Menu for the CXAS SCRAPI Cymbal Pools Demo
--------------------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs & grant IAM roles
 (2) Install CXAS SCRAPI
 (3) Create the app & pull it locally
 (4) Scaffold the agent & author instructions
 (5) Author the scheduling tools
 (6) Add a slot-filling callback
 (7) Lint and push the agent
 (8) Preview & manually test the agent
 (9) Author a guardrail
(10) Write goldens, tool tests & callback tests
(11) Run CI/CD tests
(12) Branch the app for experiments
(13) Split off a second agent (multi-agent architecture)
(14) Install the Antigravity CLI
(15) Vibe-code: convert tools to use variables
(16) Vibe-code: golden eval & guardrail refinement
(17) Run local simulations
(18) Agent-foundry: build an agent from a PRD
(19) Create a voice variant
(20) Enable Cloud Logging & trace a conversation
(21) View Insights quality scorecards
(22) Show in-class demo prompts
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
        echo "$ gcloud auth application-default login --quiet # cxas authenticates via ADC, not the gcloud CLI account, so this must be set explicitly" | pv -qL 100
        gcloud auth application-default login --quiet
        gcloud auth application-default set-quota-project $GCP_PROJECT --quiet 2>/dev/null
        gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        sed -i "s/^export GCP_PROJECT=.*/export GCP_PROJECT=$GCP_PROJECT/" $PROJDIR/.env
        source $PROJDIR/.env
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** CX Agent Studio location is $CXAS_LOCATION ***" | pv -qL 100
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
                echo
                echo "$ gcloud auth application-default login --quiet # cxas authenticates via ADC, not the gcloud CLI account, so this must be set explicitly" | pv -qL 100
                gcloud auth application-default login --quiet
                gcloud auth application-default set-quota-project $GCP_PROJECT --quiet 2>/dev/null
                gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                sed -i "s/^export GCP_PROJECT=.*/export GCP_PROJECT=$GCP_PROJECT/" $PROJDIR/.env
                source $PROJDIR/.env
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** CX Agent Studio location is $CXAS_LOCATION ***" | pv -qL 100
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
export APIS="aiplatform.googleapis.com dialogflow.googleapis.com cloudbuild.googleapis.com run.googleapis.com bigquery.googleapis.com storage.googleapis.com cloudtrace.googleapis.com logging.googleapis.com"
export ROLES="roles/aiplatform.user roles/dialogflow.admin roles/storage.objectAdmin roles/bigquery.dataViewer roles/bigquery.dataEditor roles/logging.viewer roles/cloudtrace.user"
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable $APIS # to enable APIs" | pv -qL 100
    echo
    for ROLE in $ROLES; do
        echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$IAM_PRINCIPAL --role=$ROLE" | pv -qL 100
    done
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    export IAM_PRINCIPAL=$(gcloud config list account --format 'value(core.account)')
    sed -i "s#^export IAM_PRINCIPAL=.*#export IAM_PRINCIPAL=$IAM_PRINCIPAL#" $PROJDIR/.env
    source $PROJDIR/.env
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable $APIS # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable $APIS
    echo
    for ROLE in $ROLES; do
        echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$IAM_PRINCIPAL --role=$ROLE" | pv -qL 100
        gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$IAM_PRINCIPAL --role=$ROLE > /dev/null 2>&1 || echo "Warning: binding $ROLE failed -- grant it manually in IAM & Admin"
    done
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** APIs are left enabled: other labs and modules in this project may depend on them ***" | pv -qL 100
    for ROLE in $ROLES; do
        echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$IAM_PRINCIPAL --role=$ROLE" | pv -qL 100
        gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$IAM_PRINCIPAL --role=$ROLE > /dev/null 2>&1 || echo "Warning: could not remove $ROLE"
    done
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
    echo "2. Grant the CXAS SCRAPI IAM roles" | pv -qL 100
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
export PATH=$PATH:/home/$USER/.local/bin:$HOME/.cargo/bin
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ curl -LsSf https://astral.sh/uv/install.sh | sh # to install the uv package manager" | pv -qL 100
    echo
    echo "$ cd \$PROJDIR && uv venv .venv && source .venv/bin/activate # to create a virtual environment" | pv -qL 100
    echo
    echo "$ uv pip install cxas-scrapi && cxas --help # to install and verify SCRAPI" | pv -qL 100
    echo
    echo "$ gcloud storage buckets create gs://\$GCS_BUCKET --project \$GCP_PROJECT --location \$CXAS_LOCATION # for eval reports" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    if ! command -v uv > /dev/null 2>&1; then
        echo
        echo "$ curl -LsSf https://astral.sh/uv/install.sh | sh # to install the uv package manager" | pv -qL 100
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin
    fi
    echo
    echo "$ cd $PROJDIR && uv venv .venv # to create a virtual environment" | pv -qL 100
    cd $PROJDIR
    uv venv .venv
    source $PROJDIR/.venv/bin/activate
    echo
    echo "$ uv pip install cxas-scrapi # to install SCRAPI" | pv -qL 100
    uv pip install cxas-scrapi
    echo
    echo "$ cxas --help # to verify SCRAPI is installed correctly" | pv -qL 100
    cxas --help
    echo
    echo "$ gcloud storage buckets create gs://$GCS_BUCKET --project $GCP_PROJECT --location $CXAS_LOCATION # for eval reports" | pv -qL 100
    gcloud storage buckets create gs://$GCS_BUCKET --project $GCP_PROJECT --location $CXAS_LOCATION 2>/dev/null || echo "*** Bucket may already exist -- continuing ***"
    if ! grep -q "# gcp-cxas-scrapi auto-activation" $HOME/.bashrc 2>/dev/null; then
        cat <<BASHRCEOF >> $HOME/.bashrc

# gcp-cxas-scrapi auto-activation -- keeps cxas on PATH and \$GCP_PROJECT/etc.
# set in every new shell/reconnect, not just the one that ran step 2. Auth
# itself (gcloud auth application-default login, from option 0) already
# persists on disk automatically -- nothing to redo here for that part.
if [ -f "$PROJDIR/.venv/bin/activate" ]; then
    source "$PROJDIR/.venv/bin/activate"
    source "$PROJDIR/.env"
fi
BASHRCEOF
        echo
        echo "*** Added auto-activation to ~/.bashrc -- new shells/reconnects will have cxas on PATH automatically ***" | pv -qL 100
    fi
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "$ gcloud storage rm -r gs://$GCS_BUCKET # to remove the eval-report bucket" | pv -qL 100
    gcloud storage rm -r gs://$GCS_BUCKET > /dev/null 2>&1 || echo "Warning: could not delete gs://$GCS_BUCKET"
    rm -rf $PROJDIR/.venv
    echo
    echo "*** Virtual environment removed. Antigravity CLI (step 14) is left installed -- it is not project-scoped ***" | pv -qL 100
else
    export STEP="${STEP},2i"
    echo
    echo "1. Install the uv package manager and create a virtual environment" | pv -qL 100
    echo "2. Install cxas-scrapi and verify with cxas --help" | pv -qL 100
    echo "3. Create a bucket for eval report backups" | pv -qL 100
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
    echo "$ cxas create \"\$APP_NAME\" --app-id \$APP_ID --project-id \$GCP_PROJECT --location \$CXAS_LOCATION --description \"Schedules pool inspection and installation visits\" # to create the app" | pv -qL 100
    echo
    echo "$ cxas pull projects/\$GCP_PROJECT/locations/\$CXAS_LOCATION/apps/\$APP_ID --target-dir \$PROJDIR # to pull it locally as \$PROJDIR/\$APP_DIR" | pv -qL 100
    echo
    echo "*** Then writes \$PROJDIR/\$APP_DIR/gecx-config.json so later steps don't need --to on every command ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR
    echo
    echo "$ cxas create \"$APP_NAME\" --app-id $APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --description \"Schedules pool inspection and installation visits\" # to create the app" | pv -qL 100
    if ! cxas create "$APP_NAME" --app-id $APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --description "Schedules pool inspection and installation visits"; then
        echo
        echo "*** cxas create failed -- this is a real backend error, not a script bug. Before retrying: ***" | pv -qL 100
        echo "*** 1. Confirm step 1 finished (APIs enabled, roles granted) and has had a minute to propagate ***" | pv -qL 100
        echo "*** 2. Visit https://ces.cloud.google.com/ once for this project to confirm CX Agent Studio is" | pv -qL 100
        echo "***    provisioned there, then rerun this step ***" | pv -qL 100
        echo "*** 3. If it's a 500/INTERNAL error, it may simply be transient -- wait a minute and retry ***" | pv -qL 100
        echo "*** 4. If '\$CXAS_LOCATION' (us) keeps failing, try 'global' instead by editing .env ***" | pv -qL 100
        echo
        echo "*** Stopping this step here -- not attempting pull, since there is nothing to pull yet ***" | pv -qL 100
    else
        echo
        echo "$ cxas pull projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --target-dir $PROJDIR # to pull it locally" | pv -qL 100
        if ! cxas pull projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --target-dir $PROJDIR; then
            echo
            echo "*** cxas pull failed right after a successful create -- rerun this step once more; the app" | pv -qL 100
            echo "*** may still be finishing provisioning on the backend ***" | pv -qL 100
        elif [ ! -d "$PROJDIR/$APP_DIR" ]; then
            echo
            echo "*** Pull reported success but $PROJDIR/$APP_DIR was not created -- if the app's display name" | pv -qL 100
            echo "*** doesn't map to 'Cymbal_Pools_Service' as expected, find the real directory with:" | pv -qL 100
            echo "*** ls $PROJDIR and update APP_DIR in $PROJDIR/.env to match ***" | pv -qL 100
        else
            cd $PROJDIR/$APP_DIR
            cat <<CONFIGEOF > gecx-config.json
{
  "gcp_project_id": "$GCP_PROJECT",
  "location": "$CXAS_LOCATION",
  "app_name": "$APP_NAME",
  "deployed_app_id": "$APP_ID",
  "app_dir": ".",
  "model": "$MODEL",
  "modality": "text",
  "default_channel": "text",
  "gcs_bucket": "gs://$GCS_BUCKET"
}
CONFIGEOF
            echo
            echo "*** Wrote $PROJDIR/$APP_DIR/gecx-config.json ***" | pv -qL 100
            echo
            echo "1. Navigate to the CX Agent Studio console at https://ces.cloud.google.com/" | pv -qL 100
            echo "2. Select project $GCP_PROJECT and verify that $APP_NAME is listed" | pv -qL 100
        fi
    fi
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "$ cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force # to delete the app" | pv -qL 100
    source $PROJDIR/.venv/bin/activate 2>/dev/null
    cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force 2>/dev/null || echo "Warning: could not delete $APP_ID automatically -- remove it from the CX Agent Studio console"
    rm -rf $PROJDIR/$APP_DIR
else
    export STEP="${STEP},3i"
    echo
    echo "1. Create the app in CX Agent Studio" | pv -qL 100
    echo "2. Pull it locally and write gecx-config.json" | pv -qL 100
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
    echo "$ mkdir -p agents # cxas local create agent requires this directory to already exist" | pv -qL 100
    echo "$ cxas local create agent \$AGENT_NAME # to scaffold agents/\$AGENT_NAME/" | pv -qL 100
    echo
    echo "*** Then writes agents/\$AGENT_NAME/instruction.txt directly with role/persona/constraints/taskflow XML tags (Instruction Design guide) ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo
    echo "$ mkdir -p agents # cxas local create agent requires this directory to already exist" | pv -qL 100
    mkdir -p agents
    echo "$ cxas local create agent $AGENT_NAME # to scaffold the agent" | pv -qL 100
    cxas local create agent $AGENT_NAME
    cat <<INSTREOF > agents/$AGENT_NAME/instruction.txt
<role>
    You are the Cymbal Pools scheduling assistant.
    Note: today's date is \${current_date}.
</role>
<persona>
    <primary_goal>
        Help customers book or reschedule a pool inspection or installation visit.
    </primary_goal>
</persona>
<constraints>
    1. Only discuss scheduling pool inspection and installation visits.
    2. Never ask for or accept a credit card, debit card, or bank account
       number in this chat -- a technician collects payment securely on site.
    3. Always confirm the service type, date, and time back to the customer
       before booking.
</constraints>
<taskflow>
    <subtask name="Scheduling">
        <step name="Collect details">
            <trigger>Customer wants to book a visit.</trigger>
            <action>
                Ask for the service type (inspection or installation) and
                preferred date, then call {@TOOL: check_availability}.
            </action>
        </step>
        <step name="Confirm and book">
            <trigger>Customer picks one of the available times.</trigger>
            <action>
                Ask for the name on the appointment, then call
                {@TOOL: book_appointment} and read back the confirmation number.
            </action>
        </step>
    </subtask>
    <subtask name="Termination">
        <step name="Goodbye">
            <trigger>Customer says bye or indicates they are done.</trigger>
            <action>
                Acknowledge the customer and end the conversation using
                {@TOOL: end_session}.
            </action>
        </step>
    </subtask>
</taskflow>
INSTREOF
    echo
    echo "*** Wrote agents/$AGENT_NAME/instruction.txt ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    rm -rf $PROJDIR/$APP_DIR/agents/$AGENT_NAME 2>/dev/null
    echo
    echo "*** Removed local agents/$AGENT_NAME -- rerun step 7 to push the deletion, or delete the app in step 3 ***" | pv -qL 100
else
    export STEP="${STEP},4i"
    echo
    echo "1. Scaffold the scheduler agent" | pv -qL 100
    echo "2. Author its instructions" | pv -qL 100
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
    echo "$ cxas local create tool check_availability python --add-to-agent \$AGENT_NAME" | pv -qL 100
    echo "$ cxas local create tool book_appointment python --add-to-agent \$AGENT_NAME" | pv -qL 100
    echo
    echo "*** Then writes tools/check_availability/python_function/python_code.py and tools/book_appointment/python_function/python_code.py directly (Tool Design guide) ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo
    echo "$ cxas local create tool check_availability python --add-to-agent $AGENT_NAME" | pv -qL 100
    cxas local create tool check_availability python --add-to-agent $AGENT_NAME
    echo
    echo "$ cxas local create tool book_appointment python --add-to-agent $AGENT_NAME" | pv -qL 100
    cxas local create tool book_appointment python --add-to-agent $AGENT_NAME
    cat <<PYEOF1 > tools/check_availability/python_function/python_code.py
def check_availability(service_type: str, preferred_date: str) -> dict:
    """Looks up available technician time slots for a pool service visit.

    Args:
        service_type (str): The type of visit ("inspection" or "installation").
        preferred_date (str): The customer's preferred date, formatted YYYY-MM-DD.

    Returns:
        dict: The service type, requested date, and available time slots.
    """
    try:
        mock_slots = ["09:00", "11:30", "14:00", "16:30"]
        return {
            "service_type": service_type,
            "preferred_date": preferred_date,
            "available_times": mock_slots,
        }
    except Exception:
        return {"agent_action": "Ask the user to try again with a different date."}
PYEOF1
    cat <<PYEOF2 > tools/book_appointment/python_function/python_code.py
def book_appointment(service_type: str, date: str, time: str, customer_name: str) -> dict:
    """Books a pool service appointment once the customer has picked a time.

    Args:
        service_type (str): The type of visit ("inspection" or "installation").
        date (str): The confirmed appointment date, formatted YYYY-MM-DD.
        time (str): The confirmed appointment time, e.g. "11:30".
        customer_name (str): The name on the appointment.

    Returns:
        dict: A confirmation number and the booked appointment details.
    """
    try:
        import hashlib
        confirmation_number = hashlib.sha1(
            f"{customer_name}{date}{time}".encode()
        ).hexdigest()[:8].upper()
        return {
            "confirmation_number": confirmation_number,
            "service_type": service_type,
            "date": date,
            "time": time,
            "customer_name": customer_name,
        }
    except Exception:
        return {"agent_action": "Ask the user to try again."}
PYEOF2
    echo
    echo "*** Wrote both tools' python_code.py ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    rm -rf $PROJDIR/$APP_DIR/tools/check_availability $PROJDIR/$APP_DIR/tools/book_appointment 2>/dev/null
    echo
    echo "*** Removed local tool directories -- rerun step 7 to push the deletion ***" | pv -qL 100
else
    export STEP="${STEP},5i"
    echo
    echo "1. Scaffold check_availability and book_appointment tools" | pv -qL 100
    echo "2. Implement each with the agent_action error-return convention" | pv -qL 100
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
    echo "*** cxas has no 'local create callback' -- confirmed by testing (agent/tool/guardrail are the only" | pv -qL 100
    echo "*** local-create templates). Callbacks are hand-created directly under the owning agent: ***" | pv -qL 100
    echo
    echo "$ mkdir -p agents/\$AGENT_NAME/before_model_callbacks/state_orchestrator" | pv -qL 100
    echo
    echo "*** Then writes python_code.py there implementing before_model_callback(callback_context, llm_request)" | pv -qL 100
    echo "*** -- confirmed by testing: that is the exact signature/location 'cxas lint' requires -- plus a" | pv -qL 100
    echo "*** colocated test.py, and wires the callback onto \$AGENT_NAME.json's before_model_callbacks list ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo
    echo "$ mkdir -p agents/$AGENT_NAME/before_model_callbacks/state_orchestrator # no 'local create callback' exists" | pv -qL 100
    mkdir -p agents/$AGENT_NAME/before_model_callbacks/state_orchestrator
    cat <<CBEOF > agents/$AGENT_NAME/before_model_callbacks/state_orchestrator/python_code.py
from typing import Optional

# CallbackContext / LlmRequest / LlmResponse are provided by the CX Agent
# Studio Python runtime at execution time -- no import is required here
# (confirmed by testing: 'cxas lint' only checks the literal annotation text).


def before_model_callback(
    callback_context: CallbackContext, llm_request: LlmRequest
) -> Optional[LlmResponse]:
    """Self-healing slot recovery for the scheduling flow.

    Mirrors CXAS SCRAPI's official Restaurant Reservation tutorial pattern:
    if the previous turn recorded a failed slot (invalid date, unavailable
    time, ...), clear it here so the agent re-asks instead of repeating the
    same failed call forever (Patterns: Slot Filling, Self-Healing).
    Returning None lets the model turn proceed normally.
    """
    state = callback_context.state
    slots = state.setdefault("slots", {})
    last_error = state.get("last_error")

    if last_error:
        slots.pop(last_error.get("slot"), None)
        state["last_error"] = None

    return None
CBEOF
    cat <<TESTEOF > agents/$AGENT_NAME/before_model_callbacks/state_orchestrator/test.py
"""Best-effort local test for state_orchestrator -- cxas test-callbacks
discovers this file automatically. The exact CallbackContext/LlmRequest
fixture pattern this pytest expects was not confirmed against a live
project; run 'cxas test-callbacks --help' and adjust the fixtures below if
this fails."""

from python_code import before_model_callback


class _FakeContext:
    def __init__(self, state):
        self.state = state


def test_clears_failed_slot():
    ctx = _FakeContext({"slots": {"preferred_date": "bad"}, "last_error": {"slot": "preferred_date"}})
    before_model_callback(ctx, None)
    assert "preferred_date" not in ctx.state["slots"]
TESTEOF
    python3 -c "
import json
p = 'agents/$AGENT_NAME/$AGENT_NAME.json'
d = json.load(open(p))
# CES round-trips this field as 'beforeModelCallbacks' (camelCase) on pull/push,
# but accepts 'before_model_callbacks' (snake_case) too -- confirmed by testing,
# having BOTH spellings present in the same file makes push fail with 'Field
# ...before_model_callbacks has already been set', so clear both before setting.
d.pop('before_model_callbacks', None)
d.pop('beforeModelCallbacks', None)
d['beforeModelCallbacks'] = [{
    'pythonCode': 'agents/$AGENT_NAME/before_model_callbacks/state_orchestrator/python_code.py',
    'description': 'Slot-filling state machine for the scheduling flow',
    'disabled': False,
}]
json.dump(d, open(p, 'w'), indent=2)
"
    echo
    echo "*** Wrote the callback, its test.py, and wired it onto $AGENT_NAME.json ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    rm -rf $PROJDIR/$APP_DIR/agents/$AGENT_NAME/before_model_callbacks/state_orchestrator 2>/dev/null
    echo
    echo "*** Removed the local callback -- rerun step 7 to push the deletion ***" | pv -qL 100
else
    export STEP="${STEP},6i"
    echo
    echo "1. Scaffold the state_orchestrator callback" | pv -qL 100
    echo "2. Implement the slot-filling state machine with a self-healing branch" | pv -qL 100
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
    echo "$ python3 -c \"...d['rootAgent']='\$AGENT_NAME'...\" # to wire the root agent" | pv -qL 100
    echo "$ python3 -c \"...append 'end_session' to \$AGENT_NAME.json's tools...\" # confirmed by testing: 'cxas lint' rule A005 requires this on the root agent" | pv -qL 100
    echo
    echo "$ cxas lint # structural check across 60+ rules" | pv -qL 100
    echo "$ cxas llm-lint --agent-dir agents/\$AGENT_NAME # AI-powered semantic review of instruction.txt" | pv -qL 100
    echo
    echo "$ cxas push --app-dir . --to projects/\$GCP_PROJECT/locations/\$CXAS_LOCATION/apps/\$APP_ID # to sync local changes" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo
    echo "$ python3 -c \"...d['rootAgent']='$AGENT_NAME'...\" # to wire the root agent" | pv -qL 100
    python3 -c "import json; d=json.load(open('app.json')); d['rootAgent']='$AGENT_NAME'; json.dump(d, open('app.json','w'), indent=2)"
    python3 -c "
import json
p = 'agents/$AGENT_NAME/$AGENT_NAME.json'
d = json.load(open(p))
if 'end_session' not in d.get('tools', []):
    d.setdefault('tools', []).append('end_session')
json.dump(d, open(p, 'w'), indent=2)
"
    echo
    echo "$ cxas lint # to check for structural issues" | pv -qL 100
    cxas lint
    echo
    echo "$ cxas llm-lint --agent-dir agents/$AGENT_NAME # to check for semantic issues in instruction.txt" | pv -qL 100
    cxas llm-lint --agent-dir agents/$AGENT_NAME 2>/dev/null || echo "*** cxas llm-lint needs Vertex AI access in \$CXAS_LOCATION -- check the error above if this warns ***"
    echo
    echo "$ cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID # to sync local changes" | pv -qL 100
    cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    echo
    echo "*** Push is a sync operation -- nothing to delete here. Delete the app itself in step 3 ***" | pv -qL 100
else
    export STEP="${STEP},7i"
    echo
    echo "1. Wire rootAgent in app.json" | pv -qL 100
    echo "2. Lint (structural and semantic) and push" | pv -qL 100
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
export STEP="${STEP},8"
echo
echo "*** Manual by design -- confirm the baseline conversation in the console ***" | pv -qL 100
echo
echo "1. Open https://ces.cloud.google.com/, select project $GCP_PROJECT, and open $APP_NAME" | pv -qL 100
echo "2. Click Preview Agent and run:" | pv -qL 100
echo "   hi" | pv -qL 100
echo "   I'd like to book a pool inspection for next Tuesday" | pv -qL 100
echo "   (pick one of the times offered)" | pv -qL 100
echo "   my name is Andrew" | pv -qL 100
echo "3. Confirm a confirmation number is read back, and click the agent's messages to see" | pv -qL 100
echo "   check_availability and book_appointment were called" | pv -qL 100
if [ $MODE -eq 2 ]; then
    echo
    read -n 1 -s -r -p $'*** Press the Enter key once the baseline conversation works ***'
    echo
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
    echo "$ cxas local create guardrail \$GUARDRAIL_NAME # scaffolds guardrails/\$GUARDRAIL_NAME/\$GUARDRAIL_NAME.json" | pv -qL 100
    echo
    echo "*** Then fills in the generated llmPolicy.prompt (trigger criteria) and action.generativeAnswer.prompt" | pv -qL 100
    echo "*** (the refusal response) directly -- both are required fields, confirmed by testing -- and pushes it" | pv -qL 100
    echo "*** (Guardrails guide) ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo "$ cxas local create guardrail $GUARDRAIL_NAME" | pv -qL 100
    cxas local create guardrail $GUARDRAIL_NAME
    python3 -c "
import json
p = 'guardrails/$GUARDRAIL_NAME/$GUARDRAIL_NAME.json'
d = json.load(open(p))
d['llmPolicy']['prompt'] = (
    '### CRITICAL RULE\n'
    '- Flag ONLY messages that contain an actual credit/debit card number, CVV, bank account number, or routing number.\n'
    '- Do NOT flag times, dates, confirmation numbers, phone numbers, or other ordinary conversational numbers.\n\n'
    '### TRIGGER CRITERIA\n'
    'FLAG the message if it contains:\n'
    '- A contiguous sequence of 13-19 digits that could be a card number (e.g. \"4111 1111 1111 1111\")\n'
    '- An explicit CVV, security code, bank account number, or routing number\n'
    '- Explicit mention of providing or requesting payment card details\n\n'
    '### DO NOT FLAG (False Positive Prevention)\n'
    'Do NOT flag ordinary conversational content such as:\n'
    '- Times (e.g. \"11:30\"), dates (e.g. \"2026-08-04\"), or short confirmation codes\n'
    '- Customer names, addresses, or general appointment details\n'
    '- Phone numbers or zip codes\n'
)
d['action']['generativeAnswer']['prompt'] = (
    \"Respond with: For your security, I can't accept payment details in this chat. \"
    'A technician will collect payment securely at the time of service.'
)
json.dump(d, open(p, 'w'), indent=2)
"
    echo
    echo "*** Filled in guardrails/$GUARDRAIL_NAME/$GUARDRAIL_NAME.json ***" | pv -qL 100
    echo
    echo "$ cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID # to publish the guardrail" | pv -qL 100
    cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID
    echo
    echo "1. In the CX Agent Studio console, open $APP_NAME > Guardrails and confirm $GUARDRAIL_NAME is listed" | pv -qL 100
    echo "2. In Preview Agent, try: my card number is 4111 1111 1111 1111" | pv -qL 100
    echo "   Confirm the guardrail's refusal message is returned" | pv -qL 100
    read -n 1 -s -r -p $'*** Press the Enter key once the guardrail is confirmed ***'
    echo
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    rm -rf $PROJDIR/$APP_DIR/guardrails/${GUARDRAIL_NAME} 2>/dev/null
    echo
    echo "*** Removed the local guardrail directory -- rerun step 7's push to sync the deletion ***" | pv -qL 100
else
    export STEP="${STEP},9i"
    echo
    echo "1. Author a guardrail that refuses payment-card details" | pv -qL 100
    echo "2. Push and test it in Preview" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"10")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"
    echo
    echo "$ mkdir -p evals/goldens evals/tool_tests" | pv -qL 100
    echo
    echo "$ cxas test-tools --app-name projects/\$GCP_PROJECT/locations/\$CXAS_LOCATION/apps/\$APP_ID --test-file evals/tool_tests/check_availability_test.yaml" | pv -qL 100
    echo "$ cxas test-tools --app-name ... --test-file evals/tool_tests/book_appointment_test.yaml" | pv -qL 100
    echo "$ cxas test-callbacks --app-dir . --agent-name \$AGENT_NAME --callback-name state_orchestrator # runs the test.py from step 6" | pv -qL 100
    echo
    echo "$ cxas push-eval --app-name ... --file evals/goldens/happy_path.yaml" | pv -qL 100
    echo "$ cxas run --app-name ... --display-name-prefix happy_path --wait # trigger evaluations -- confirmed by testing: cxas run requires an explicit --evaluation-id/--display-name-prefix/--tags filter, there is no 'run everything' bare invocation" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    mkdir -p evals/goldens evals/tool_tests
    cat <<GOLDEOF > evals/goldens/happy_path.yaml
conversations:
  - conversation: happy_path
    turns:
      - user: "hi"
      - user: "I'd like to book a pool inspection for 2026-08-04"
        tool_calls:
          - action: check_availability
            args:
              service_type: inspection
              preferred_date: "2026-08-04"
      - user: "11:30 works, my name is Andrew"
        tool_calls:
          - action: book_appointment
            args:
              service_type: inspection
              date: "2026-08-04"
              time: "11:30"
              customer_name: Andrew
GOLDEOF
    cat <<TOOLTEST1 > evals/tool_tests/check_availability_test.yaml
tests:
  - name: check_availability_test
    tool: check_availability
    args:
      service_type: inspection
      preferred_date: "2026-08-04"
    expectations:
      response:
        - path: "\$.result.available_times"
          operator: length_greater_than
          value: 0
TOOLTEST1
    cat <<TOOLTEST2 > evals/tool_tests/book_appointment_test.yaml
tests:
  - name: book_appointment_test
    tool: book_appointment
    args:
      service_type: inspection
      date: "2026-08-04"
      time: "11:30"
      customer_name: Andrew
    expectations:
      response:
        - path: "\$.result.confirmation_number"
          operator: is_not_null
TOOLTEST2
    echo
    echo "$ cxas test-tools --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --test-file evals/tool_tests/check_availability_test.yaml" | pv -qL 100
    cxas test-tools --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --test-file evals/tool_tests/check_availability_test.yaml
    echo
    echo "$ cxas test-tools --app-name ... --test-file evals/tool_tests/book_appointment_test.yaml" | pv -qL 100
    cxas test-tools --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --test-file evals/tool_tests/book_appointment_test.yaml
    echo
    echo "$ cxas test-callbacks --app-dir . --agent-name $AGENT_NAME --callback-name state_orchestrator" | pv -qL 100
    cxas test-callbacks --app-dir . --agent-name $AGENT_NAME --callback-name state_orchestrator 2>/dev/null || echo "*** test.py's fixture pattern from step 6 is best-effort -- run 'cxas test-callbacks --help' and adjust it if this fails ***"
    echo
    echo "$ cxas push-eval --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --file evals/goldens/happy_path.yaml" | pv -qL 100
    cxas push-eval --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --file evals/goldens/happy_path.yaml
    echo
    echo "$ cxas run --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --display-name-prefix happy_path --wait" | pv -qL 100
    cxas run --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --display-name-prefix happy_path --wait
    echo
    echo "*** Open the app's Evaluations tab in the console to see the golden's run history ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10x"
    rm -rf $PROJDIR/$APP_DIR/evals/goldens $PROJDIR/$APP_DIR/evals/tool_tests 2>/dev/null
    echo
    echo "*** Removed local eval definitions -- remove their platform-side records from the Evaluations tab if needed ***" | pv -qL 100
else
    export STEP="${STEP},10i"
    echo
    echo "1. Write a golden and two tool tests" | pv -qL 100
    echo "2. Run them locally (plus step 6's callback test) and push the golden to the platform" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"11")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},11i"
    echo
    echo "$ cxas ci-test --app-dir . --project-id \$GCP_PROJECT --location \$CXAS_LOCATION # full CI lifecycle against a temporary app" | pv -qL 100
    echo "$ cxas local-test --app-dir . --project-id \$GCP_PROJECT --location \$CXAS_LOCATION # CI testing inside a local Docker container" | pv -qL 100
    echo "$ cxas init-github-action --app-dir . --project-id \$GCP_PROJECT --location \$CXAS_LOCATION # scaffold .github/workflows" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo
    echo "$ cxas ci-test --app-dir . --project-id $GCP_PROJECT --location $CXAS_LOCATION" | pv -qL 100
    cxas ci-test --app-dir . --project-id $GCP_PROJECT --location $CXAS_LOCATION 2>/dev/null || echo "*** cxas ci-test needs cloudbuild.googleapis.com and may take a few minutes -- check its output above for the real failure if this warns ***"
    if command -v docker > /dev/null 2>&1; then
        echo
        echo "$ cxas local-test --app-dir . --project-id $GCP_PROJECT --location $CXAS_LOCATION" | pv -qL 100
        cxas local-test --app-dir . --project-id $GCP_PROJECT --location $CXAS_LOCATION 2>/dev/null || echo "*** cxas local-test failed -- confirm the Docker daemon is running ***"
    else
        echo
        echo "*** Docker is not available in this environment -- skipping cxas local-test ***" | pv -qL 100
    fi
    echo
    echo "$ cxas init-github-action --app-dir . --project-id $GCP_PROJECT --location $CXAS_LOCATION" | pv -qL 100
    cxas init-github-action --app-dir . --project-id $GCP_PROJECT --location $CXAS_LOCATION 2>/dev/null || echo "*** cxas init-github-action needs a git remote to infer the GitHub repo -- pass --github-repo owner/repo if this warns ***"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"
    rm -rf $PROJDIR/$APP_DIR/.github 2>/dev/null
    echo
    echo "*** Removed the generated GitHub Actions workflow (if any). Temporary apps created by cxas ci-test clean themselves up ***" | pv -qL 100
else
    export STEP="${STEP},11i"
    echo
    echo "1. Run the full CI test lifecycle against a temporary app" | pv -qL 100
    echo "2. Run local Docker-based CI tests" | pv -qL 100
    echo "3. Scaffold a GitHub Actions workflow" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"12")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},12i"
    echo
    echo "$ cxas branch projects/\$GCP_PROJECT/locations/\$CXAS_LOCATION/apps/\$APP_ID --new-name \"\$BRANCH_APP_NAME\" --project-id \$GCP_PROJECT --location \$CXAS_LOCATION" | pv -qL 100
    echo
    echo "*** cxas branch pull -> creates -> pushes a NEW app with an auto-generated ID -- confirmed by testing," | pv -qL 100
    echo "*** there is no flag to set a custom app-id here (unlike 'cxas create'), so the script looks up the" | pv -qL 100
    echo "*** resulting ID afterward with 'cxas apps list' and saves it to \$PROJDIR/.env as \$BRANCH_APP_ID ***" | pv -qL 100
    echo
    echo "*** Steps 13-19 operate on this branch, so the tested baseline app from steps 3-10 stays untouched ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},12"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR
    echo
    echo "$ cxas branch projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --new-name \"$BRANCH_APP_NAME\" --project-id $GCP_PROJECT --location $CXAS_LOCATION" | pv -qL 100
    cxas branch projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --new-name "$BRANCH_APP_NAME" --project-id $GCP_PROJECT --location $CXAS_LOCATION
    echo
    echo "$ cxas apps list --project-id $GCP_PROJECT --location $CXAS_LOCATION # to look up the branch's generated app ID" | pv -qL 100
    export BRANCH_RESOURCE=$(cxas apps list --project-id $GCP_PROJECT --location $CXAS_LOCATION 2>/dev/null | grep "$BRANCH_APP_NAME" | awk '{print $NF}' | tail -1)
    export BRANCH_APP_ID=$(basename "$BRANCH_RESOURCE")
    sed -i "s#^export BRANCH_APP_ID=.*#export BRANCH_APP_ID=$BRANCH_APP_ID#" $PROJDIR/.env
    source $PROJDIR/.env
    echo
    echo "*** Branch app ID captured: $BRANCH_APP_ID ***" | pv -qL 100
    echo
    echo "$ cxas pull projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID --target-dir $PROJDIR" | pv -qL 100
    cxas pull projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID --target-dir $PROJDIR
    cat <<CONFIGEOF > $PROJDIR/$BRANCH_APP_DIR/gecx-config.json
{
  "gcp_project_id": "$GCP_PROJECT",
  "location": "$CXAS_LOCATION",
  "app_name": "$BRANCH_APP_NAME",
  "deployed_app_id": "$BRANCH_APP_ID",
  "app_dir": ".",
  "model": "$MODEL",
  "modality": "text",
  "default_channel": "text",
  "gcs_bucket": "gs://$GCS_BUCKET"
}
CONFIGEOF
    echo
    echo "*** Branch $BRANCH_APP_ID pulled to $PROJDIR/$BRANCH_APP_DIR -- steps 13-19 work here ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},12x"
    if [ "$BRANCH_APP_ID" != "NOT_SET" ]; then
        echo
        echo "$ cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force" | pv -qL 100
        source $PROJDIR/.venv/bin/activate 2>/dev/null
        cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force 2>/dev/null || echo "Warning: could not delete $BRANCH_APP_ID automatically -- remove it from the console"
        sed -i "s#^export BRANCH_APP_ID=.*#export BRANCH_APP_ID=NOT_SET#" $PROJDIR/.env
    else
        echo
        echo "*** No branch app ID recorded in .env -- remove it from the CX Agent Studio console manually ***" | pv -qL 100
    fi
    rm -rf $PROJDIR/$BRANCH_APP_DIR
else
    export STEP="${STEP},12i"
    echo
    echo "1. Branch the tested app into a working copy" | pv -qL 100
    echo "2. Pull the branch locally for the remaining experimental steps" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"13")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},13i"
    echo
    echo "$ mkdir -p agents; cxas local create agent \$FAQ_AGENT_NAME # scaffold a second, general-purpose agent" | pv -qL 100
    echo
    echo "*** Then writes its instruction.txt, and adds it to \$AGENT_NAME.json's child_agents list -- confirmed by" | pv -qL 100
    echo "*** testing: 'child_agents' (not 'subAgents') is the real field on the Agent schema for this. Whether" | pv -qL 100
    echo "*** the scheduler also needs a 'transfer_rules' entry to actually route to it live was not confirmed --" | pv -qL 100
    echo "*** check the CX Agent Studio console's agent transfer settings if routing doesn't trigger in Preview ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},13"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$BRANCH_APP_DIR
    echo
    echo "$ cxas local create agent $FAQ_AGENT_NAME" | pv -qL 100
    cxas local create agent $FAQ_AGENT_NAME
    cat <<FAQEOF > agents/$FAQ_AGENT_NAME/instruction.txt
<role>
    You are the Cymbal Pools general FAQ assistant.
    Note: today's date is \${current_date}.
</role>
<persona>
    <primary_goal>
        Answer general pool-care questions (chemical balance, filter
        maintenance, opening/closing a pool for the season).
    </primary_goal>
</persona>
<constraints>
    1. Do not attempt to book or modify appointments -- transfer back to the
       scheduling agent if the customer wants to schedule a visit.
</constraints>
FAQEOF
    python3 -c "
import json
path = 'agents/$AGENT_NAME/$AGENT_NAME.json'
d = json.load(open(path))
# Same camelCase/snake_case collision as before_model_callbacks (step 6): CES
# round-trips this field as 'childAgents' -- normalize to that single spelling
# so a repeat run after a pull doesn't leave both keys set and break push.
existing = d.pop('childAgents', None) or d.pop('child_agents', None) or []
if '$FAQ_AGENT_NAME' not in existing:
    existing.append('$FAQ_AGENT_NAME')
d['childAgents'] = existing
json.dump(d, open(path, 'w'), indent=2)
"
    echo
    echo "*** Added $FAQ_AGENT_NAME as a child_agent of $AGENT_NAME (Agent Architecture guide: split only once a second, genuinely distinct responsibility appears) ***" | pv -qL 100
    echo
    echo "$ cxas lint" | pv -qL 100
    cxas lint
    echo
    echo "$ cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID" | pv -qL 100
    cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},13x"
    rm -rf $PROJDIR/$BRANCH_APP_DIR/agents/$FAQ_AGENT_NAME 2>/dev/null
    echo
    echo "*** Removed the local FAQ agent -- rerun this branch's push to sync the deletion, or drop the whole branch in step 12 ***" | pv -qL 100
else
    export STEP="${STEP},13i"
    echo
    echo "1. Scaffold a second FAQ agent" | pv -qL 100
    echo "2. Wire it as a sub-agent of the scheduler" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"14")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},14i"
    echo
    echo "$ curl -fsSL https://antigravity.google/cli/install.sh | bash # to install the Antigravity CLI" | pv -qL 100
    echo
    echo "$ cd \$PROJDIR/\$BRANCH_APP_DIR && cxas init # to install the CXAS SCRAPI skills for Antigravity" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},14"
    echo
    echo "$ curl -fsSL https://antigravity.google/cli/install.sh | bash # to install the Antigravity CLI" | pv -qL 100
    curl -fsSL https://antigravity.google/cli/install.sh | bash
    export PATH=$PATH:$HOME/.antigravity/bin:$HOME/.local/bin
    if ! command -v agy > /dev/null 2>&1; then
        echo
        echo "*** agy is not on PATH yet -- check the installer's own output above for its install directory and add it to PATH ***" | pv -qL 100
    fi
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$BRANCH_APP_DIR
    echo
    echo "$ cxas init # to install the CXAS SCRAPI skills" | pv -qL 100
    cxas init
else
    export STEP="${STEP},14i"
    echo
    echo "1. Install the Antigravity CLI (agy)" | pv -qL 100
    echo "2. Install the CXAS SCRAPI skills with cxas init" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"15")
start=`date +%s`
source $PROJDIR/.env
export STEP="${STEP},15"
echo
echo "*** Vibe-coding step -- this hands control to the interactive Antigravity CLI ***" | pv -qL 100
echo
echo "1. cd $PROJDIR/$BRANCH_APP_DIR && run: agy" | pv -qL 100
echo "2. Authenticate with a Google Cloud project as prompted (device-code flow), select $GCP_PROJECT and $CXAS_LOCATION" | pv -qL 100
echo "3. Type /cxas to see the available skills, then paste this prompt:" | pv -qL 100
echo
echo "   given the current cxas scrapi agent, change the check_availability and" | pv -qL 100
echo "   book_appointment tools into dynamic functions using CX Agent variables," | pv -qL 100
echo "   so that multiple appointments can be tracked and checked." | pv -qL 100
echo
echo "4. Approve any access requests, then type /exit" | pv -qL 100
if [ $MODE -eq 2 ]; then
    echo
    read -n 1 -s -r -p $'*** Press the Enter key once you have exited Antigravity ***'
    echo
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$BRANCH_APP_DIR
    echo
    echo "$ cxas lint" | pv -qL 100
    cxas lint
    echo
    echo "$ cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID" | pv -qL 100
    cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"16")
start=`date +%s`
source $PROJDIR/.env
export STEP="${STEP},16"
echo
echo "*** Vibe-coding step -- run agy again from $PROJDIR/$BRANCH_APP_DIR ***" | pv -qL 100
echo
echo "1. Paste this prompt to create a golden from a sample conversation:" | pv -qL 100
echo
echo "   create a golden evaluation from the following conversation and place" | pv -qL 100
echo "   it in the evals/goldens folder:" | pv -qL 100
echo "   hi" | pv -qL 100
echo "   Hello! I'm the Cymbal Pools scheduling assistant. Would you like to" | pv -qL 100
echo "   book an inspection or an installation visit?" | pv -qL 100
echo "   an inspection next Tuesday" | pv -qL 100
echo "   Here are the available times for that date: 09:00, 11:30, 14:00, 16:30." | pv -qL 100
echo "   Which works best?" | pv -qL 100
echo
echo "2. Then paste this prompt to add regression coverage for the guardrail:" | pv -qL 100
echo
echo "   Add two local simulations for the $GUARDRAIL_NAME guardrail: one confirming" | pv -qL 100
echo "   a message with a real card number is refused, and one confirming a normal" | pv -qL 100
echo "   booking conversation (picking a time like 11:30 and giving a name) is NOT" | pv -qL 100
echo "   blocked -- this guardrail previously false-triggered on ordinary times and" | pv -qL 100
echo "   confirmation numbers, so guard against regressing that." | pv -qL 100
echo
echo "3. Approve any access requests, then type /exit" | pv -qL 100
if [ $MODE -eq 2 ]; then
    echo
    read -n 1 -s -r -p $'*** Press the Enter key once you have exited Antigravity ***'
    echo
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$BRANCH_APP_DIR
    echo
    echo "$ cxas lint" | pv -qL 100
    cxas lint
    echo
    echo "$ cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID" | pv -qL 100
    cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"17")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},17i"
    echo
    echo "$ cxas evals report --run --include sims --app-name projects/\$GCP_PROJECT/locations/\$CXAS_LOCATION/apps/\$BRANCH_APP_ID --output-dir eval-reports --sim-parallel 5" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},17"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$BRANCH_APP_DIR
    echo
    echo "$ cxas evals report --run --include sims --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID --output-dir eval-reports --sim-parallel 5" | pv -qL 100
    cxas evals report \
        --run \
        --include sims \
        --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$BRANCH_APP_ID \
        --output-dir "eval-reports" \
        --sim-parallel 5
    echo
    echo "*** Local Simulations use an AI-powered user simulator (Gemini) to try to reach a goal, then Gemini judges whether the agent met it -- inspect eval-reports/ for the transcript and verdict ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},17x"
    rm -rf $PROJDIR/$BRANCH_APP_DIR/eval-reports 2>/dev/null
else
    export STEP="${STEP},17i"
    echo
    echo "1. Run every golden, tool test, callback test, and simulation together" | pv -qL 100
    echo "2. Inspect the generated report" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"18")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},18i"
    echo
    echo "$ cxas create \"\$FOUNDRY_APP_NAME\" --app-id \$FOUNDRY_APP_ID --project-id \$GCP_PROJECT --location \$CXAS_LOCATION --description \"Built by the agent-foundry skill from a PRD\"" | pv -qL 100
    echo
    echo "*** Then writes a short PRD, runs cxas init, and hands control to agy with: \"Use the cxas-scrapi skill called agent-foundry to build a new agent using the Cymbal Pools Membership PRD\" ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},18"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR
    echo
    echo "$ cxas create \"$FOUNDRY_APP_NAME\" --app-id $FOUNDRY_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --description \"Built by the agent-foundry skill from a PRD\"" | pv -qL 100
    cxas create "$FOUNDRY_APP_NAME" --app-id $FOUNDRY_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --description "Built by the agent-foundry skill from a PRD"
    echo
    echo "$ cxas pull projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$FOUNDRY_APP_ID --target-dir $PROJDIR" | pv -qL 100
    cxas pull projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$FOUNDRY_APP_ID --target-dir $PROJDIR
    mkdir -p $PROJDIR/$FOUNDRY_APP_DIR/prds
    cat <<PRDEOF > $PROJDIR/$FOUNDRY_APP_DIR/prds/cymbal_pools_membership_prd.md
# Cymbal Pools Membership Agent -- PRD

## Goal
Answer questions about the Cymbal Pools annual maintenance membership plan
(Basic, Standard, Premium tiers) and let a customer sign up for one.

## Tools needed
- get_membership_tiers: returns tier names, monthly price, and included visits.
- enroll_member: takes a tier name and customer name, returns a member ID.

## Constraints
- Never accept payment card or bank details in chat.
- Always read back the chosen tier's price before enrolling.
PRDEOF
    cd $PROJDIR/$FOUNDRY_APP_DIR
    echo
    echo "$ cxas init" | pv -qL 100
    cxas init
    echo
    echo "*** Wrote prds/cymbal_pools_membership_prd.md ***" | pv -qL 100
    echo
    echo "1. cd $PROJDIR/$FOUNDRY_APP_DIR && run: agy" | pv -qL 100
    echo "2. Type /cxas, then paste this prompt:" | pv -qL 100
    echo
    echo "   Use the cxas-scrapi skill called agent-foundry to build a new agent" | pv -qL 100
    echo "   using the PRD at prds/cymbal_pools_membership_prd.md" | pv -qL 100
    echo
    echo "3. Approve any access requests, then type /exit" | pv -qL 100
    read -n 1 -s -r -p $'*** Press the Enter key once agent-foundry has finished ***'
    echo
    echo
    echo "$ cxas lint" | pv -qL 100
    cxas lint
    echo
    echo "$ cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$FOUNDRY_APP_ID" | pv -qL 100
    cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$FOUNDRY_APP_ID
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},18x"
    echo
    echo "$ cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$FOUNDRY_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force" | pv -qL 100
    source $PROJDIR/.venv/bin/activate 2>/dev/null
    cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$FOUNDRY_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force 2>/dev/null || echo "Warning: could not delete $FOUNDRY_APP_ID automatically -- remove it from the console"
    rm -rf $PROJDIR/$FOUNDRY_APP_DIR
else
    export STEP="${STEP},18i"
    echo
    echo "1. Create a second app and bundle a short PRD" | pv -qL 100
    echo "2. Use the agent-foundry skill in Antigravity to build the agent from it" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"19")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},19i"
    echo
    echo "$ cxas create \"\$VOICE_APP_NAME\" --app-id \$VOICE_APP_ID --project-id \$GCP_PROJECT --location \$CXAS_LOCATION" | pv -qL 100
    echo
    echo "*** cxas branch has no custom-app-id flag (confirmed by testing -- it always assigns a random UUID)," | pv -qL 100
    echo "*** so this step instead creates a fresh app with a real app-id, copies the tested \$APP_DIR content" | pv -qL 100
    echo "*** locally, edits gecx-config.json to modality: audio / model: \$VOICE_MODEL, and pushes it over ***" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},19"
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR
    echo
    echo "$ cxas create \"$VOICE_APP_NAME\" --app-id $VOICE_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION" | pv -qL 100
    cxas create "$VOICE_APP_NAME" --app-id $VOICE_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --description "Voice variant of $APP_NAME"
    echo
    echo "$ cp -r $PROJDIR/$APP_DIR $PROJDIR/$VOICE_APP_DIR # reuse the tested agent/tools/callback/guardrail as-is" | pv -qL 100
    rm -rf $PROJDIR/$VOICE_APP_DIR
    cp -r $PROJDIR/$APP_DIR $PROJDIR/$VOICE_APP_DIR
    cat <<VOICECONFIG > $PROJDIR/$VOICE_APP_DIR/gecx-config.json
{
  "gcp_project_id": "$GCP_PROJECT",
  "location": "$CXAS_LOCATION",
  "app_name": "$VOICE_APP_NAME",
  "deployed_app_id": "$VOICE_APP_ID",
  "app_dir": ".",
  "model": "$VOICE_MODEL",
  "modality": "audio",
  "default_channel": "audio",
  "gcs_bucket": "gs://$GCS_BUCKET"
}
VOICECONFIG
    cd $PROJDIR/$VOICE_APP_DIR
    echo
    echo "$ cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$VOICE_APP_ID" | pv -qL 100
    cxas push --app-dir . --to projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$VOICE_APP_ID
    echo
    echo "1. In the CX Agent Studio console, open $VOICE_APP_NAME and click Preview Agent" | pv -qL 100
    echo "2. Confirm a microphone/voice input control is available (modality: audio, model: $VOICE_MODEL)" | pv -qL 100
    echo "3. Speak: I'd like to book a pool inspection, and confirm the agent responds with voice" | pv -qL 100
    read -n 1 -s -r -p $'*** Press the Enter key once the voice conversation is confirmed ***'
    echo
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},19x"
    echo
    echo "$ cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$VOICE_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force" | pv -qL 100
    source $PROJDIR/.venv/bin/activate 2>/dev/null
    cxas delete --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$VOICE_APP_ID --project-id $GCP_PROJECT --location $CXAS_LOCATION --force 2>/dev/null || echo "Warning: could not delete $VOICE_APP_ID automatically -- remove it from the console"
    rm -rf $PROJDIR/$VOICE_APP_DIR
else
    export STEP="${STEP},19i"
    echo
    echo "1. Create a voice-variant app and reuse the tested agent locally" | pv -qL 100
    echo "2. Switch modality/model to audio and push" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"20")
start=`date +%s`
source $PROJDIR/.env
export STEP="${STEP},20"
echo
echo "*** No confirmed API for the Cloud Logging toggle -- console step, then cxas trace reads it ***" | pv -qL 100
echo
echo "1. Open $APP_NAME in the CX Agent Studio console" | pv -qL 100
echo "2. Click Settings > Advanced > Enable Cloud Logging" | pv -qL 100
if [ $MODE -eq 2 ]; then
    read -n 1 -s -r -p $'*** Press the Enter key once Cloud Logging is enabled ***'
    echo
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo
    echo "$ cxas trace list --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --limit 5" | pv -qL 100
    cxas trace list --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID --limit 5
    echo
    echo "$ cxas trace open --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID # prints/opens the console URL" | pv -qL 100
    cxas trace open --app-name projects/$GCP_PROJECT/locations/$CXAS_LOCATION/apps/$APP_ID 2>/dev/null
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"21")
start=`date +%s`
source $PROJDIR/.env
export STEP="${STEP},21"
echo
echo "*** Insights (CCAI Quality scorecards) -- best-effort CLI, console-verified ***" | pv -qL 100
if [ $MODE -eq 2 ]; then
    source $PROJDIR/.venv/bin/activate
    cd $PROJDIR/$APP_DIR
    echo
    echo "$ cxas insights list-scorecards --parent projects/$GCP_PROJECT/locations/$CXAS_LOCATION # 'cxas insights list' has no such subcommand -- confirmed by testing" | pv -qL 100
    cxas insights list-scorecards --parent projects/$GCP_PROJECT/locations/$CXAS_LOCATION 2>/dev/null || echo "*** No scorecards yet, or this needs a scorecard created first via 'cxas insights create-scorecard' -- see the console instead ***"
fi
echo
echo "1. In the console, open $APP_NAME > Insights" | pv -qL 100
echo "2. Review the QA scorecard results from the conversations run in step 8" | pv -qL 100
if [ $MODE -eq 2 ]; then
    echo
    read -n 1 -s -r -p $'*** Press the Enter key once you have reviewed the scorecards ***'
    echo
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"22")
start=`date +%s`
source $PROJDIR/.env
export STEP="${STEP},22"
echo
echo "*** Read each prompt aloud, then run it in Preview Agent for the relevant app ***" | pv -qL 100
echo
echo "--- Baseline scheduler ($APP_NAME) ---" | pv -qL 100
echo "hi" | pv -qL 100
echo "I'd like to book a pool inspection for next Tuesday" | pv -qL 100
echo "my name is Andrew" | pv -qL 100
echo
echo "--- Guardrail ---" | pv -qL 100
echo "my card number is 4111 1111 1111 1111, can you charge it now?" | pv -qL 100
echo
echo "--- Multi-agent FAQ routing (branch app) ---" | pv -qL 100
echo "how often should I check my pool's chlorine level?" | pv -qL 100
echo "actually, can you book me an installation visit instead?" | pv -qL 100
echo
echo "--- Voice variant ($VOICE_APP_NAME) ---" | pv -qL 100
echo "(speak) I'd like to book a pool inspection" | pv -qL 100
echo
echo "--- Agent-foundry ($FOUNDRY_APP_NAME) ---" | pv -qL 100
echo "what membership tiers do you offer?" | pv -qL 100
echo "sign me up for the Standard tier, I'm Diana" | pv -qL 100
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
 /|            /         /              / /              /
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

Ⓒ Tech Equity 2026" | pv -qL 100
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
