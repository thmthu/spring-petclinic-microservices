#!/bin/bash

# 1. Khai báo các biến
PREFIX_RELEASE="ci-6da8086d"
NAMESPACE="ci-6da8086d" 
IMAGE_TAG="ci-6da8086d"
IMAGE_TAG_GATEWAY="ci-096dcab4"

# --- KIỂM TRA VÀ TẠO NAMESPACE ---
if ! kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Namespace ${NAMESPACE} không tồn tại. Đang tiến hành tạo mới..."
    kubectl create ns "${NAMESPACE}"
    # Chỉ dán nhãn khi tạo mới hoặc nếu chắc chắn muốn ghi đè
    kubectl label namespace "${NAMESPACE}" istio-injection=enabled
else
    echo "Namespace ${NAMESPACE} đã tồn tại. Bỏ qua bước tạo."
    # Đảm bảo namespace đã có label cho Istio (nếu chưa có)
    kubectl label namespace "${NAMESPACE}" istio-injection=enabled --overwrite
fi

# 2. Thực thi Helm Upgrade/Install
echo "Đang triển khai các dịch vụ..."

# Service: Config
helm upgrade --install config-server-${PREFIX_RELEASE} deployment-k8s/service-config \
    --namespace ${NAMESPACE} \
    --set config.image.tag=${IMAGE_TAG}

# Service: Customer
helm upgrade --install customer-service-${PREFIX_RELEASE} deployment-k8s/service-customer \
    --namespace ${NAMESPACE} \
    --set customers.image.tag=${IMAGE_TAG}

# Service: Vets
helm upgrade --install vets-service-${PREFIX_RELEASE} deployment-k8s/service-vets \
    --namespace ${NAMESPACE} \
    --set vets.image.tag=${IMAGE_TAG}

# Service: Visit
helm upgrade --install visit-service-${PREFIX_RELEASE} deployment-k8s/service-visit \
    --namespace ${NAMESPACE} \
    --set visits.image.tag=${IMAGE_TAG}

# Service: Api-Gateway (Đã sửa tên release để không trùng với customer-service)
helm upgrade --install api-gateway-${PREFIX_RELEASE} deployment-k8s/service-api-gateway \
    --namespace ${NAMESPACE} \
    --set gateway.image.tag=${IMAGE_TAG_GATEWAY}

echo "Triển khai hoàn tất! Đang kiểm tra trạng thái Pods..."
kubectl get pods -n ${NAMESPACE}

# --- TRIỂN KHAI ISTIO RESOURCES ---
echo ""
echo "Đang triển khai Istio Gateway và VirtualService..."

# Thay đổi namespace trong Istio resources trước khi apply
# Gateway: Chỉ thay namespace trong metadata
sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" deployment-k8s/istio/gateway.yaml | kubectl apply -f -

# VirtualService: Thay namespace trong metadata và FQDN của services
sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
    -e "s/\.petclinic\.svc\.cluster\.local/.${NAMESPACE}.svc.cluster.local/g" \
    deployment-k8s/istio/virtualservice.yaml | kubectl apply -f -

# DestinationRule: Thay namespace trong metadata và host pattern
sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
    -e "s/\*\.petclinic\.svc\.cluster\.local/*.${NAMESPACE}.svc.cluster.local/g" \
    deployment-k8s/istio/destinationRule.yaml | kubectl apply -f -

echo ""
echo "Đang kiểm tra Istio Gateway..."
kubectl get gateway -n ${NAMESPACE}
kubectl get virtualservice -n ${NAMESPACE}

echo ""
echo "==================================="
echo "TRIỂN KHAI HOÀN TẤT!"
echo "==================================="
echo ""
echo "Để truy cập UI từ máy local, chạy lệnh:"
echo "kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
echo ""
echo "Sau đó truy cập: http://localhost:8080"
echo "==================================="