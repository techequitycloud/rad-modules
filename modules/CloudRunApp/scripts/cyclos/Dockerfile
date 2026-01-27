ARG APP_VERSION=4.16.15
FROM cyclos/cyclos:${APP_VERSION}
# Simple wrapper to allow mirroring/building via the custom pipeline

COPY cyclos.properties ${CYCLOS_HOME}/WEB-INF/classes/
COPY hazelcast.xml ${CYCLOS_HOME}/WEB-INF/classes/
