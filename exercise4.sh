oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    prometheusK8s:
      retention: 7d
      volumeClaimTemplate:
      spec:
        storageClassName: ocs-storagecluster-ceph-rbd
        resources:
          requests:
            storage: 40Gi
EOF