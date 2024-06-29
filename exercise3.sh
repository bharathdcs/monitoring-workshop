#CPU cores used per Cloud Pak for Data product
sort_desc(sum(max(kube_pod_labels{namespace="zen", label_icpdsupport_add_on_id!="" }) by (label_icpdsupport_add_on_id,pod) * on(pod) group_right(label_icpdsupport_add_on_id)max(kube_pod_container_resource_limits{resource="cpu",unit="core",namespace="zen"}) by (pod)) by (label_icpdsupport_add_on_id))

#Red and write speed
avg by (instance) (irate(node_disk_io_time_seconds_total[5m])/1000) * on (instance) group_left (nodename) node_uname_info

#Free disk space
node_filesystem_free_bytes{mountpoint ="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100

#CPU Utilization
avg by (instance, nodename)(irate(node_cpu_seconds_total{mode!="idle"}[5m])) * 100 * on (instance) group_left (nodename) node_uname_info

#Memory utilization
100 * ((node_memory_MemTotal_bytes -(node_memory_MemFree_bytes+node_memory_Buffers_bytes+node_memory_Cached_bytes))/node_memory_MemTotal_bytes) * on (instance) group_left (nodename) node_uname_info


#CPU USage compared to limit
topk(25, sort_desc(100*sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{namespace="zen"}) by (pod) / sum(kube_pod_container_resource_limits{resource="cpu",unit="core",namespace="zen"}) by (pod)))

#last terminated reason
kube_pod_container_status_last_terminated_reason{reason="Error"}