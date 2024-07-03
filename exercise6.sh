#!/bin/bash

print_usage() {
  echo ""
  echo "cluster_resource_utilization: Prometheus API calls to show OpenShift cluster resource use"
  echo ""
  echo "options:"
  echo "--csv         write output sections to CSV files"
  echo "-q, --quiet   quiet the display of results in the terminal"
  echo "-h, --help    show help"
  exit 0
}

write_csv() {
  # csv header $1, result $2, filename $3
  echo " - ${3}"
  echo "${1}${2}" > "${3}"
}

display_result() {
  # banner $1, result data $2
  echo "# ------------------------------------------------------------------------------"
  echo "# ${1}"
  echo "# ------------------------------------------------------------------------------"
  echo "${2}"
  echo ""
}

WRITE_CSV="false"
SHOW_DISPLAY="true"

for arg in "$@"
do
  case $arg in
    --csv)
    WRITE_CSV="true"
    shift
    ;;
    -q|--quiet)
    SHOW_DISPLAY="false"
    shift
    ;;
    -h|--help)
    print_usage
    ;;
  esac
done

if [[ -n ${OCP_TOKEN} ]]; then
  oc login --token=${OCP_TOKEN} --server=${OCP_URL} > /dev/null 2>&1
elif [[ -n ${OCP_PASSWORD} ]]; then
  oc login ${OCP_URL} -u=${OCP_USERNAME} -p=${OCP_PASSWORD} --insecure-skip-tls-verify > /dev/null 2>&1
fi

TOKEN=$(oc whoami -t)
if [[ -z ${TOKEN} || -z ${PROJECT_CPD_INST_OPERANDS} ]]; then
  echo "OpenShift login unsuccessful. Please verify the credentials stored in your environment (PROJECT_CPD_INST_OPERANDS, OCP_URL, OCP_USERNAME, OCP_PASSWORD/OCP_TOKEN)."
  exit
fi

CLUSTER_NAME=$(oc whoami --show-server | sed -e 's/^http:\/\///g' -e 's/^https:\/\///g' -e 's/^api.//g' -e 's/:6443//g')
PROM_OCP_ROUTE=$(oc get route prometheus-k8s -n openshift-monitoring | grep -w prometheus-k8s | tr -s ' ' | cut -d " " -f2)
PROM_URL="https://${PROM_OCP_ROUTE}"

TOP10_MEM_BANNER="Top 10 memory-consuming pods, ${PROJECT_CPD_INST_OPERANDS} namespace: <pod>, <memory GB>"
TOP10_MEM_QUERY="topk(10, max(container_memory_working_set_bytes{namespace=\"${PROJECT_CPD_INST_OPERANDS}\",container!=\"\",pod!=\"\"}) by (pod) ) / 10^9"
TOP10=$(curl --globoff -s -k -X POST -H "Authorization: Bearer ${TOKEN}" \
-g "${PROM_URL}/api/v1/query" \
--data-urlencode "query=${TOP10_MEM_QUERY}" | \
jq -r '.data.result[] | .metric.pod + ", " + (((.value[1]|tonumber)*100|round/100)|tostring) + "GB"')

CPU_PER_NODE_BANNER="CPU utilization per node, 5min interval: <node name>, <node cpu seconds>"
CPU_PER_NODE=$(curl --globoff -s -k -X POST -H "Authorization: Bearer ${TOKEN}" \
-g "${PROM_URL}/api/v1/query" \
--data-urlencode 'query=(avg by (instance, nodename)(irate(node_cpu_seconds_total{mode!="idle"}[5m]))) *100 * on (instance) group_left (nodename) node_uname_info' | \
jq -r '.data.result[] | .metric.nodename + ", " + (((.value[1]|tonumber)*100|round/100)|tostring)')

MEM_PER_NODE_BANNER="Memory utilization per node: <node name>, <memory usage %>"
MEM_PER_NODE=$(curl --globoff -s -k -X POST -H "Authorization: Bearer ${TOKEN}" \
-g "${PROM_URL}/api/v1/query" \
--data-urlencode 'query=(100 * ((node_memory_MemTotal_bytes -(node_memory_MemFree_bytes+node_memory_Buffers_bytes+node_memory_Cached_bytes))/node_memory_MemTotal_bytes) * on (instance) group_left (nodename) node_uname_info)' | \
jq -r '.data.result[] | .metric.nodename + ", " + (((.value[1]|tonumber)*100|round/100)|tostring) + "%"')

NET_IO_PER_NODE_BANNER="Network I/O per node, 5min interval: <node name>, <I/O KB>"
NET_IO_PER_NODE=$(curl --globoff -s -k -X POST -H "Authorization: Bearer ${TOKEN}" \
-g "${PROM_URL}/api/v1/query" \
--data-urlencode 'query=(avg by (instance) ((irate(node_network_receive_bytes_total[5m]) + irate(node_network_transmit_bytes_total[5m])) ) * on (instance) group_left (nodename) node_uname_info / 10^3)' | \
jq -r '.data.result[] | .metric.nodename + ", " + (((.value[1]|tonumber)*100|round/100)|tostring) + "KB"')

OCP_API_HTTP_STATS_BANNER="OpenShift API call statuses: <HTTP code>, <count over last 30min>"
OCP_API_HTTP_STATS=$(curl --globoff -s -k -X POST -H "Authorization: Bearer ${TOKEN}" \
-g "${PROM_URL}/api/v1/query" \
--data-urlencode 'query=sum by (code)(rate(apiserver_request_total{verb=~"POST|PUT|DELETE|PATCH|GET|LIST|WATCH"}[30m]))' | \
jq -r '.data.result[] | .metric.code + ", " + (((.value[1]|tonumber)|round)|tostring)')

if [[ ${SHOW_DISPLAY} = "true" ]]; then
  echo ""
  echo "#==============================================================================="
  echo "# Cluster resource utililzation: ${CLUSTER_NAME}"
  echo "#==============================================================================="
  echo ""
  display_result "${TOP10_MEM_BANNER}" "${TOP10}"
  display_result "${CPU_PER_NODE_BANNER}" "${CPU_PER_NODE}"
  display_result "${MEM_PER_NODE_BANNER}" "${MEM_PER_NODE}"
  display_result "${NET_IO_PER_NODE_BANNER}" "${NET_IO_PER_NODE}"
  display_result "${OCP_API_HTTP_STATS_BANNER}" "${OCP_API_HTTP_STATS}"
  echo ""
fi

if [[ ${WRITE_CSV} = "true" ]]; then
  WORKING_DIR=$(pwd)
  echo "# Writing cluster resource utililzation result files to: ${WORKING_DIR}"
  write_csv $'pod,mem_gb\n' "${TOP10}" "cluster_mem_top10_pods.csv"
  write_csv $'node,cpu_seconds\n' "${CPU_PER_NODE}" "cluster_cpu_seconds_per_node.csv"
  write_csv $'node,mem_usage_pct\n' "${MEM_PER_NODE}" "cluster_mem_usage_per_node.csv"
  write_csv $'node,net_io_kb\n' "${NET_IO_PER_NODE}" "cluster_net_io_per_node.csv"
  write_csv $'http_code,count\n' "${OCP_API_HTTP_STATS}" "cluster_api_http_stats.csv"
  echo ""
fi