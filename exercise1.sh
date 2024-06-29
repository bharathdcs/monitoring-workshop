echo "Simulate Ephemeral storage failures"

oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: test-ephemeral
  name: test-ephemeral
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: test-ephemeral
  strategy:
    type: Recreate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: test-ephemeral
    spec:
      containers:
      - image: registry.access.redhat.com/ubi8/ubi:8.10-901.1717584420
        imagePullPolicy: IfNotPresent
        name: test-ephemeral
        command: ["sleep", "360"]
        resources:
          limits:
            memory: 128Mi
            cpu: 500m
            ephemeral-storage: 100Mi    
      restartPolicy: Always
EOF

echo "wait for deployment to start"
oc wait --for=condition=Ready pod -l app=test-ephemeral

sleep 15
echo "Triggering the error"
oc exec -it deploy/test-ephemeral -- bash -c "/usr/bin/dd if=/dev/zero of=/tmp/zerofile1 bs=15000 count=10000"

