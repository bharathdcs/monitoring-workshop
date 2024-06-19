oc apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cpd-monitor
  namespace: zen
spec:
  endpoints:
  - interval: 30s
    port: zenwatchdog-notls
    scheme: http
  selector:
    matchLabels:
      app: zen-adv
EOF
