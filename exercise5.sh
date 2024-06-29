oc apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: zenmetrics
  namespace: zen
spec:
  endpoints:
    - interval: 5m
      port: zenwatchdog-tls
      scheme: https
      tlsConfig:
        insecureSkipVerify: true
  selector:
    matchLabels:
      component: zen-watchdog
EOF