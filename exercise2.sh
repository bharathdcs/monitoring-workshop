oc create -n openshift-monitoring \
configmap cluster-monitoring-config --from-file config.yaml=metrics-storage.yml