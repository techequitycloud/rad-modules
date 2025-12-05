#!/bin/bash
# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PROJECT_ID=$1
APP_VERSION=$2
APP_DOWNLOAD_FILEID=$3
SERVICE_ACCOUNT=$4

if [ -n "${SERVICE_ACCOUNT}" ] 
then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectViewer" --no-user-output-enabled 
fi

if ! command -v gdown &> /dev/null; then
    pip install --user gdown
    ~/.local/bin/gdown "https://drive.google.com/uc?id=${APP_DOWNLOAD_FILEID}"
else
    gdown "https://drive.google.com/uc?id=${APP_DOWNLOAD_FILEID}"
fi

unzip -q -o cyclos-${APP_VERSION}.zip -d $(pwd)

echo "Listing files in $(pwd):"
ls -la

# sed -i 's/cyclos\.clusterHandler = none/cyclos\.clusterHandler = hazelcast/g' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties

sed -i 's/cyclos\.header\.remoteAddress =/cyclos.header.remoteAddress = X-Forwarded-For/g' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties

sed -i 's/cyclos\.header\.protocol =/cyclos.header.protocol = X-Forwarded-Proto/g' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties

sed -i '/cyclos.header.protocol/a \# Header containing the URI of the original request. The de-facto standard value is X-Forwarded-URI\n\ cyclos.header.uri = X-Forwarded-URI' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties && sed -i 's/ cyclos.header.uri = X-Forwarded-URI/cyclos.header.uri = X-Forwarded-URI/' cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties

if ! grep -q "cyclos\.db\.skipLock = true" cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties; then echo "cyclos.db.skipLock = true" | cat - cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties > $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties.temp && mv cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties.temp cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties; fi

sed -i 's/<multicast enabled="true">/<multicast enabled="false"><\/multicast>/g' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/hazelcast.xml

sed -i 's/    <multicast-group>224\.2\.2\.3<\/multicast-group>/<kubernetes enabled="true">/g' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/hazelcast.xml

sed -i 's/<multicast-port>54327<\/multicast-port>/<service-dns>${CLUSTER_K8S_DNS}<\/service-dns>/g' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/hazelcast.xml

sed -i '/^\s*<\/multicast>$/s/<\/multicast>/<\/kubernetes>/g' $(pwd)/cyclos-${APP_VERSION}/web/WEB-INF/classes/hazelcast.xml

cat <<EOF > $(pwd)/Dockerfile # to create Dockerfile
FROM tomcat:9-jdk17-temurin
ENV JAVA_OPTS "-DCLUSTER_K8S_DNS=\\\$CLUSTER_K8S_DNS"
RUN apt-get update && apt-get install -y ca-certificates openssl fonts-dejavu && mkdir -p /usr/local/cyclos && mkdir -p /var/log/cyclos && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY cyclos-${APP_VERSION}/web/ /usr/local/cyclos/
COPY cyclos-${APP_VERSION}/web/WEB-INF/classes/cyclos-docker.properties /usr/local/cyclos/WEB-INF/classes/cyclos.properties
WORKDIR /usr/local/cyclos
RUN rm -rf /usr/local/tomcat/webapps/*
RUN ln -s /usr/local/cyclos /usr/local/tomcat/webapps/ROOT
VOLUME /var/log/cyclos
EOF
  
# Attempt to submit the build
if ! gcloud --project="${PROJECT_ID}" builds submit . --config cloudbuild.yaml $SA_ARG; then
    echo "Initial build failed, retrying..."
    sleep 60  # Wait before retrying
    if ! gcloud --project="${PROJECT_ID}" builds submit . --config cloudbuild.yaml $SA_ARG; then
        echo "Retry build failed as well. Exiting."
        exit 1
    fi
fi

rm -rf cyclos-${APP_VERSION}*

