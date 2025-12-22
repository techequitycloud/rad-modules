FROM tomcat:9-jdk17-temurin
ENV JAVA_OPTS "-DCLUSTER_K8S_DNS=\$CLUSTER_K8S_DNS"
RUN apt-get update && apt-get install -y ca-certificates openssl fonts-dejavu && mkdir -p /usr/local/cyclos && mkdir -p /var/log/cyclos && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY cyclos-4.16.15/web/ /usr/local/cyclos/
COPY cyclos-4.16.15/web/WEB-INF/classes/cyclos-docker.properties /usr/local/cyclos/WEB-INF/classes/cyclos.properties
WORKDIR /usr/local/cyclos
RUN rm -rf /usr/local/tomcat/webapps/*
RUN ln -s /usr/local/cyclos /usr/local/tomcat/webapps/ROOT
VOLUME /var/log/cyclos
