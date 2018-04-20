## vm-pnda1, vm-pnda-hadoop-cm

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: CM
roles:
  - hadoop_manager
  - platform_testing_cdh
  - mysql_connector
  - pnda_restart
```

## vm-pnda2, vm-pnda-hadoop-mgr-1

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: MGR01
roles:
  - mysql_connector
```

## vm-pnda3, vm-pnda-hadoop-mgr-2

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: MGR02
roles:
  - mysql_connector
```

## vm-pnda4, vm-pnda-hadoop-mgr-3

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: MGR03
roles:
  - mysql_connector
```

## vm-pnda5, vm-pnda-hadoop-mgr-4

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: MGR04
roles:
  - oozie_database
  - mysql_connector
```

## vm-pnda6, vm-pnda-hadoop-dn-0

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: DATANODE
```

## vm-pnda7, vm-pnda-hadoop-dn-1

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: DATANODE
```

## vm-pnda8, vm-pnda-hadoop-dn-2

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: DATANODE
```

## vm-pnda9, vm-pnda-opentsdb-0

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
roles:
  - opentsdb
  - grafana
```

## vm-pnda10, vm-pnda-logserver

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
roles:
  - elk
  - logserver
  - kibana_dashboard
```

## vm-pnda11, vm-pnda-zk-0

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
roles:
  - zookeeper
cluster: zkvm-pnda
```

## vm-pnda12, vm-pnda-kafka-0

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
roles:
  - kafka
  - kafka_tool
broker_id: 0
vlans:
  pnda: ens3
  ingest: ens4
```

## vm-pnda13, vm-pnda-saltmaster

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
```

## vm-pnda14, vm-pnda-jupyter

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: EDGE
roles:
  - jupyter
```

## vm-pnda15, vm-pnda-tools

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
roles:
  - kafka_manager
  - platform_testing_general
  - elk
```

## vm-pnda16

Formerly Percona MySQL Cluster node one

Use as additional datanode or kafka/zookeeper?

## vm-pnda17

Formerly Percona MySQL Cluster node two

Use as additional datanode or kafka/zookeeper?

## vm-pnda18

Formerly Percona MySQL Cluster node three

Use as additional datanode or kafka/zookeeper?

## vm-pnda19, vm-pnda-edge

```
pnda:
  flavor: standard
  is_new_node: True
hadoop.distro: 'HDP'

pnda_cluster: vm-pnda
hadoop:
  role: EDGE
roles:
  - hadoop_edge
  - console_frontend
  - console_backend_data_logger
  - console_backend_data_manager
  - graphite
  - gobblin
  - deployment_manager
  - package_repository
  - data_service
  - impala-shell
  - yarn-gateway
  - hbase_opentsdb_tables
  - hdfs_cleaner
  - master_dataset
```

