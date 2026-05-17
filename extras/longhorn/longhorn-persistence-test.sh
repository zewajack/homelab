#!/bin/bash
set -e

NAMESPACE=default
PVC_NAME=longhorn-test-pvc
POD1=writer-pod
POD2=reader-pod
TEST_FILE=/data/hello.txt
TEST_DATA="Hello from Longhorn $(date)"

echo "▶ Creating PVC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

echo "▶ Waiting for PVC to be Bound..."
for i in {1..30}; do
  STATUS=$(kubectl get pvc ${PVC_NAME} -n ${NAMESPACE} -o jsonpath='{.status.phase}')
  if [ "$STATUS" = "Bound" ]; then
    echo "✔ PVC is Bound"
    break
  fi
  echo "  PVC status: $STATUS (retry $i)"
  sleep 2
done

if [ "$STATUS" != "Bound" ]; then
  echo "❌ PVC did not bind"
  kubectl describe pvc ${PVC_NAME} -n ${NAMESPACE}
  exit 1
fi

echo "▶ Creating writer pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD1}
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "echo '${TEST_DATA}' > ${TEST_FILE}; sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: data-vol
  volumes:
  - name: data-vol
    persistentVolumeClaim:
      claimName: ${PVC_NAME}
EOF

kubectl wait pod/${POD1} --for=condition=Ready -n ${NAMESPACE}

echo "▶ Verifying data written..."
kubectl exec -n ${NAMESPACE} ${POD1} -- cat ${TEST_FILE}

echo "▶ Deleting writer pod..."
kubectl delete pod ${POD1} -n ${NAMESPACE}

echo "▶ Creating reader pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD2}
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: reader
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: data-vol
  volumes:
  - name: data-vol
    persistentVolumeClaim:
      claimName: ${PVC_NAME}
EOF

kubectl wait pod/${POD2} --for=condition=Ready -n ${NAMESPACE}

echo "▶ Checking persisted data..."
kubectl exec -n ${NAMESPACE} ${POD2} -- cat ${TEST_FILE}

echo "✅ SUCCESS: Data persisted via Longhorn"

cleanup() {
  echo "▶ Running cleanup..."
  kubectl delete pod ${POD1} ${POD2} -n ${NAMESPACE} --ignore-not-found
  kubectl delete pvc ${PVC_NAME} -n ${NAMESPACE} --ignore-not-found
}
trap cleanup EXIT