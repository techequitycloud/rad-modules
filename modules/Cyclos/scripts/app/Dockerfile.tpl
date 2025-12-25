FROM cyclos/cyclos:${APP_VERSION}
ADD cyclos.properties $CYCLOS_HOME/WEB-INF/classes
ADD hazelcast.xml $CYCLOS_HOME/WEB-INF/classes
