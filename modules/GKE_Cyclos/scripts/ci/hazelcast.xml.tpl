<?xml version="1.0" encoding="UTF-8"?>

<!-- This file is used when cyclos.clusterHandler is set to hazelcast in 
    cyclos.properties. -->
<hazelcast xmlns="http://www.hazelcast.com/schema/config"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.hazelcast.com/schema/config
    http://www.hazelcast.com/schema/config/hazelcast-config-5.0.xsd">

    <cluster-name>cyclos</cluster-name>

    <network>
        <port auto-increment="true">5701</port>
        
        <!-- NOTICE:
        Starting with Cyclos 4.16, an easier way to set the join strategy
        is to use one of the following environment variables. When one of these is set,
        any <join> tags are ignored, and the corresponding join kind is used.
        See https://documentation.cyclos.org/current/cyclos-reference/#setup-adjustments-clustering
        -->
               
        <join>
            <multicast enabled="false" />
            <kubernetes enabled="true">
                <service-dns>${CLUSTER_K8S_DNS}</service-dns>
            </kubernetes>
        </join>
    </network>

    <!-- Both initializations and tasks maps need to never expire, and have 
        some backups, as they need to be kept alive for the entire cluster lifecycle -->
    <map name="cyclos.map.initializations">
        <backup-count>3</backup-count>
    </map>

    <!-- It is advised that the session timeout map has a backup -->
    <map name="cyclos.map.sharedStorage.SESSION_TIMEOUTS">
        <backup-count>1</backup-count>
        <read-backup-data>true</read-backup-data>
    </map>

    <scheduled-executor-service name="recurringTaskScheduledExecutor">
        <durability>0</durability>
        <!-- Pool size is configured through cyclos.properties with cyclos.maxRecurringTasks -->
    </scheduled-executor-service>

    <!-- Executor used only to run system monitor tasks -->
    <executor-service name="systemMonitorExecutor">
        <pool-size>4</pool-size>
    </executor-service>

</hazelcast>