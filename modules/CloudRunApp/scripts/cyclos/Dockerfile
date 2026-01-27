ARG APP_VERSION=4.16.15
FROM cyclos/cyclos:${APP_VERSION}
# Simple wrapper to allow mirroring/building via the custom pipeline

COPY cyclos.properties /usr/local/cyclos/WEB-INF/classes/
COPY hazelcast.xml /usr/local/cyclos/WEB-INF/classes/
