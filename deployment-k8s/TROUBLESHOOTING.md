# Troubleshooting Guide

## Các lỗi đã fix

### 1. Config Server Connection Refused
**Triệu chứng:**
```
Connection refused to http://localhost:8888/
```

**Nguyên nhân:** Service đang dùng localhost thay vì Kubernetes service DNS.

**Giải pháp:** Đã thêm biến môi trường:
```yaml
- name: CONFIG_SERVER_URL
  value: "http://config-server:8888"
```

### 2. Tracing Server DNS Resolution Failed
**Triệu chứng:**
```
Failed to resolve 'tracing-server'
Dropped spans due to WebClientRequestException
```

**Nguyên nhân:** Zipkin tracing server không được deploy trong K8s cluster.

**Giải pháp:** Disable tracing cho environment K8s:
```yaml
- name: MANAGEMENT_ZIPKIN_TRACING_ENDPOINT
  value: ""
- name: MANAGEMENT_TRACING_ENABLED
  value: "false"
- name: SPRING_ZIPKIN_ENABLED
  value: "false"
```

### 3. Discovery Server Dependency
**Triệu chứng:** InitContainer wait for discovery-server bị timeout.

**Giải pháp:** Đã xóa dependency discovery-server khỏi initContainers.

## Quick Fix Commands

### Re-deploy services với config mới:
```bash
# Set namespace
NAMESPACE="ci-6da8086d"
PREFIX_RELEASE="ci-6da8086d"

# Re-deploy API Gateway
helm upgrade --install api-gateway-${PREFIX_RELEASE} deployment-k8s/service-api-gateway \
    --namespace ${NAMESPACE} \
    --set gateway.image.tag=ci-096dcab4

# Re-deploy Customers
helm upgrade --install customer-service-${PREFIX_RELEASE} deployment-k8s/service-customer \
    --namespace ${NAMESPACE} \
    --set customers.image.tag=ci-6da8086d

# Re-deploy Vets
helm upgrade --install vets-service-${PREFIX_RELEASE} deployment-k8s/service-vets \
    --namespace ${NAMESPACE} \
    --set vets.image.tag=ci-6da8086d

# Re-deploy Visits
helm upgrade --install visit-service-${PREFIX_RELEASE} deployment-k8s/service-visit \
    --namespace ${NAMESPACE} \
    --set visits.image.tag=ci-6da8086d
```

### Hoặc chạy toàn bộ:
```bash
./deployment-k8s/deployheal.sh
```

### Kiểm tra logs sau khi deploy:
```bash
kubectl logs -f deployment/api-gateway -n ${NAMESPACE}
kubectl logs -f deployment/customers-service -n ${NAMESPACE}
```

## Verify Services

### Check pod status:
```bash
kubectl get pods -n ${NAMESPACE}
```

### Check service endpoints:
```bash
kubectl get svc -n ${NAMESPACE}
kubectl get endpoints -n ${NAMESPACE}
```

### Test health endpoints:
```bash
kubectl exec -it deployment/api-gateway -n ${NAMESPACE} -- wget -qO- http://config-server:8888/actuator/health
kubectl exec -it deployment/api-gateway -n ${NAMESPACE} -- wget -qO- http://customers-service:8081/actuator/health
```
