pipeline {
    agent {
        label 'host-node'
    }
    tools {
        nodejs 'Node_23'
    }
    environment {
        DOCKER_REGISTRY = 'thmtthu1'
        COMMIT_HASH = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
        NAMESPACE = "ci-${COMMIT_HASH}"
        IMAGE_TAG = "ci-${COMMIT_HASH}"
        PREFIX_RELEASE = "ci-${COMMIT_HASH}"
        ZAP_REPORT_DIR = "zap-reports"
        ZAP_VERSION = "stable"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code..."
                checkout scm
            }
        }
        stage('Build & Test') {
            steps {
                sh 'mvn clean verify'
            }
        }
        stage('Build and Push Docker Images') {
            steps {
                script {
                    echo "Building all Docker images with tag ${IMAGE_TAG} using Maven"
                    sh """
                        ./mvnw clean install -P buildDocker -DskipTests \
                            -Ddocker.image.tag=${IMAGE_TAG} \
                            -Ddocker.image.prefix=${DOCKER_REGISTRY}
                    """
                    
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-creds-thmthu',
                            usernameVariable: 'DOCKERHUB_USER',
                            passwordVariable: 'DOCKERHUB_PASS'
                        )
                    ]) {
                        echo "Logging in to Docker Hub"
                        sh """
                            echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin
                        """

                        echo "Pushing images to Docker Hub"
                        sh """
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-config-server:${IMAGE_TAG} > /dev/null
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-customers-service:${IMAGE_TAG} > /dev/null
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-vets-service:${IMAGE_TAG} > /dev/null
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-visits-service:${IMAGE_TAG} > /dev/null
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-api-gateway:${IMAGE_TAG} > /dev/null

                        """
                    }
                   
                }
            }
        }
        
        stage('Update Helm Values') {
            steps {
                script {
                    echo "Updating Helm values files with tag ${IMAGE_TAG}"
                    
                    // Update service-config values.yaml
                    sh """
                        sed -i 's|tag: ".*"|tag: "${IMAGE_TAG}"|g' deployment-k8s/service-config/values.yaml
                    """
                    
                    // Update service-customer values.yaml
                    sh """
                        sed -i 's|tag: ".*"|tag: "${IMAGE_TAG}"|g' deployment-k8s/service-customer/values.yaml
                    """
                    
                    // Update service-vets values.yaml
                    sh """
                        sed -i 's|tag: ".*"|tag: "${IMAGE_TAG}"|g' deployment-k8s/service-vets/values.yaml
                    """
                    
                    // Update service-visit values.yaml
                    sh """
                        sed -i 's|tag: ".*"|tag: "${IMAGE_TAG}"|g' deployment-k8s/service-visit/values.yaml
                    """
                }
            }
        }
        
        stage('Create Namespace with Istio') {
            steps {
                script {
                    echo "Creating namespace ${NAMESPACE} with Istio injection enabled"
                    sh """
                        if ! kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
                            echo "Creating namespace ${NAMESPACE}..."
                            kubectl create namespace ${NAMESPACE}
                            kubectl label namespace ${NAMESPACE} istio-injection=enabled
                        else
                            echo "Namespace ${NAMESPACE} already exists"
                            kubectl label namespace ${NAMESPACE} istio-injection=enabled --overwrite
                        fi
                    """
                }
            }
        }
        
        stage('Deploy Services') {
            parallel {
                stage('Deploy Config Server') {
                    steps {
                        script {
                            echo "Deploying config-server to namespace ${NAMESPACE}"
                            sh """
                                helm upgrade --install config-server-${PREFIX_RELEASE} deployment-k8s/service-config \
                                    --namespace ${NAMESPACE} \
                                    --set config.image.tag=${IMAGE_TAG} 
                            """
                        }
                    }
                }
                
                stage('Deploy Customers Service') {
                    steps {
                        script {
                            echo "Deploying customers-service to namespace ${NAMESPACE}"
                            sh """
                                helm upgrade --install customer-service-${PREFIX_RELEASE} deployment-k8s/service-customer \
                                    --namespace ${NAMESPACE} \
                                    --set customers.image.tag=${IMAGE_TAG} 
                            """
                        }
                    }
                }
                
                stage('Deploy Vets Service') {
                    steps {
                        script {
                            echo "Deploying vets-service to namespace ${NAMESPACE}"
                            sh """
                                helm upgrade --install vets-service-${PREFIX_RELEASE} deployment-k8s/service-vets \
                                    --namespace ${NAMESPACE} \
                                    --set vets.image.tag=${IMAGE_TAG} 
                            """
                        }
                    }
                }
                
                stage('Deploy Visits Service') {
                    steps {
                        script {
                            echo "Deploying visits-service to namespace ${NAMESPACE}"
                            sh """
                                helm upgrade --install visit-service-${PREFIX_RELEASE} deployment-k8s/service-visit \
                                    --namespace ${NAMESPACE} \
                                    --set visits.image.tag=${IMAGE_TAG} 
                            """
                        }
                    }
                }
                
                stage('Deploy API Gateway') {
                    steps {
                        script {
                            echo "Deploying api-gateway to namespace ${NAMESPACE}"
                            sh """
                                helm upgrade --install api-gateway-${PREFIX_RELEASE} deployment-k8s/service-api-gateway \
                                    --namespace ${NAMESPACE} \
                                    --set gateway.image.tag=${IMAGE_TAG} 
                            """
                        }
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    echo "Verifying deployment in namespace ${NAMESPACE}"
                    sh """
                        kubectl get pods -n ${NAMESPACE}
                        kubectl get services -n ${NAMESPACE}
                    """
                }
            }
        }
        
        stage('Deploy Istio Resources') {
            steps {
                script {
                    echo "Deploying Istio Gateway and VirtualService to namespace ${NAMESPACE}"
                    
                    // Deploy Gateway
                    sh """
                        sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
                            deployment-k8s/istio/gateway.yaml | kubectl apply -f -
                    """
                    
                    // Deploy VirtualService
                    sh """
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \\
                            -e "s/\\.petclinic\\.svc\\.cluster\\.local/.${NAMESPACE}.svc.cluster.local/g" \\
                            deployment-k8s/istio/virtualservice.yaml | kubectl apply -f -
                    """
                    
                    // Deploy DestinationRule
                    sh """
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \\
                            -e "s/\\*\\.petclinic\\.svc\\.cluster\\.local/*.${NAMESPACE}.svc.cluster.local/g" \\
                            deployment-k8s/istio/destinationRule.yaml | kubectl apply -f -
                    """
                    
                    echo "Deploying Istio AuthorizationPolicies..."
                    
                    // Authorization for Config Server
                    sh """
                        sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
                            deployment-k8s/istio/authorization-config.yaml | kubectl apply -f -
                    """
                    
                    // Authorization for Customers Service
                    sh """
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \\
                            -e "s/cluster\\.local\\/ns\\/petclinic\\//cluster.local\\/ns\\/${NAMESPACE}\\//g" \\
                            deployment-k8s/istio/authorization-customer.yaml | kubectl apply -f -
                    """
                    
                    // Apply PeerAuthentication for mTLS
                    echo "Deploying PeerAuthentication for mTLS..."
                    sh """
                        sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
                            deployment-k8s/istio/PeerAuthentication.yaml | kubectl apply -f -
                    """
                }
            }
        }
        
        stage('Verify Istio Configuration') {
            steps {
                script {
                    echo "Verifying Istio resources in namespace ${NAMESPACE}"
                    sh """
                        echo "=== Istio Gateways ==="
                        kubectl get gateway -n ${NAMESPACE}
                        
                        echo ""
                        echo "=== Istio VirtualServices ==="
                        kubectl get virtualservice -n ${NAMESPACE}
                        
                        echo ""
                        echo "=== Istio DestinationRules ==="
                        kubectl get destinationrule -n ${NAMESPACE}
                        
                        echo ""
                        echo "=== Istio AuthorizationPolicies ==="
                        kubectl get authorizationpolicy -n ${NAMESPACE}
                        
                        echo ""
                        echo "=== Istio Ingress Gateway Status ==="
                        kubectl get svc istio-ingressgateway -n istio-system
                    """
                }
            }
        }
        
        stage('Wait for Pods Ready') {
            steps {
                script {
                    echo "Waiting for all pods to be ready in namespace ${NAMESPACE}"
                    sh """
                        kubectl wait --for=condition=ready pod --all -n ${NAMESPACE} --timeout=300s || true
                        echo ""
                        echo "=== Pod Status ==="
                        kubectl get pods -n ${NAMESPACE}
                    """
                }
            }
        }
        
        stage('Deploy ZAP Baseline Scans') {
            steps {
                script {
                    echo "Deploying OWASP ZAP Baseline Scan jobs for all services in namespace ${NAMESPACE}"
                    sh """
                        # Deploy ZAP scanner service account
                        sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \\
                            deployment-k8s/dast-zap/serviceaccount.yaml | kubectl apply -f -
                        
                        # Deploy baseline scans for all services
                        cat deployment-k8s/dast-zap/dast-zap.yaml | \\
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \\
                            -e "s/\\.petclinic\\.svc\\.cluster\\.local/.${NAMESPACE}.svc.cluster.local/g" | \\
                        kubectl apply -n ${NAMESPACE} -f -
                        
                        echo "Deployed ZAP baseline scans for:"
                        kubectl get jobs -n ${NAMESPACE} -l scan-type=baseline
                    """
                }
            }
        }
        
        stage('Wait for ZAP Baseline Scans') {
            steps {
                script {
                    echo "Waiting for all ZAP Baseline Scans to complete..."
                    sh """
                        # Wait for all baseline scan jobs
                        for job in zap-baseline-scan-gateway zap-baseline-scan-customers zap-baseline-scan-vets zap-baseline-scan-visits; do
                            echo "Waiting for \$job..."
                            kubectl wait --for=condition=complete job/\$job \
                                -n ${NAMESPACE} --timeout=600s || true
                        done
                        
                        echo "\nBaseline scan jobs status:"
                        kubectl get jobs -n ${NAMESPACE} -l scan-type=baseline
                    """
                }
            }
        }
        
        stage('Retrieve ZAP Baseline Reports') {
            steps {
                script {
                    echo "Retrieving ZAP Baseline Scan reports from all services"
                    sh """
                        # Create report directory
                        mkdir -p ${ZAP_REPORT_DIR}/baseline
                        
                        # Retrieve reports from API Gateway
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=api-gateway,scan-type=baseline -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving API Gateway baseline reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/baseline/ 2>/dev/null || true
                        fi
                        
                        # Retrieve reports from Customers Service
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=customers,scan-type=baseline -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving Customers service baseline reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/baseline/ 2>/dev/null || true
                        fi
                        
                        # Retrieve reports from Vets Service
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=vets,scan-type=baseline -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving Vets service baseline reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/baseline/ 2>/dev/null || true
                        fi
                        
                        # Retrieve reports from Visits Service
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=visits,scan-type=baseline -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving Visits service baseline reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/baseline/ 2>/dev/null || true
                        fi
                        
                        echo "\nBaseline reports retrieved:"
                        ls -lh ${ZAP_REPORT_DIR}/baseline/
                    """
                }
            }
        }
        
        stage('Deploy ZAP Active Scans') {
            steps {
                script {
                    echo "Deploying OWASP ZAP Active Scans for all services in namespace ${NAMESPACE}"
                    sh """
                        # Deploy active scans for all services
                        cat deployment-k8s/dast-zap/dast-zap.yaml | \\
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \\
                            -e "s/\\.petclinic\\.svc\\.cluster\\.local/.${NAMESPACE}.svc.cluster.local/g" | \\
                        grep -A 100 "scan-type: active" | \\
                        kubectl apply -n ${NAMESPACE} -f -
                        
                        echo "Deployed ZAP active scans for:"
                        kubectl get jobs -n ${NAMESPACE} -l scan-type=active
                    """
                }
            }
        }
        
        stage('Wait for ZAP Active Scans') {
            steps {
                script {
                    echo "Waiting for all ZAP Active Scans to complete..."
                    sh """
                        # Wait for all active scan jobs
                        for job in zap-active-scan-gateway zap-active-scan-customers zap-active-scan-vets zap-active-scan-visits; do
                            echo "Waiting for \$job..."
                            kubectl wait --for=condition=complete job/\$job \
                                -n ${NAMESPACE} --timeout=900s || true
                        done
                        
                        echo "\nActive scan jobs status:"
                        kubectl get jobs -n ${NAMESPACE} -l scan-type=active
                    """
                }
            }
        }
        
        stage('Retrieve ZAP Active Reports') {
            steps {
                script {
                    echo "Retrieving ZAP Active Scan reports from all services"
                    sh """
                        mkdir -p ${ZAP_REPORT_DIR}/active
                        
                        # Retrieve reports from API Gateway
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=api-gateway,scan-type=active -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving API Gateway active reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/active/ 2>/dev/null || true
                        fi
                        
                        # Retrieve reports from Customers Service
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=customers,scan-type=active -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving Customers service active reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/active/ 2>/dev/null || true
                        fi
                        
                        # Retrieve reports from Vets Service
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=vets,scan-type=active -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving Vets service active reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/active/ 2>/dev/null || true
                        fi
                        
                        # Retrieve reports from Visits Service
                        POD=\$(kubectl get pods -n ${NAMESPACE} -l service=visits,scan-type=active -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                        if [ -n "\$POD" ]; then
                            echo "Retrieving Visits service active reports from \$POD"
                            kubectl cp ${NAMESPACE}/\$POD:/zap/wrk/. ${ZAP_REPORT_DIR}/active/ 2>/dev/null || true
                        fi
                        
                        echo "\nActive scan reports retrieved:"
                        ls -lh ${ZAP_REPORT_DIR}/active/
                        
                        # Show summary from all pods
                        echo "\n=== ZAP Active Scan Logs Summary ==="
                        for service in api-gateway customers vets visits; do
                            POD=\$(kubectl get pods -n ${NAMESPACE} -l service=\$service,scan-type=active -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
                            if [ -n "\$POD" ]; then
                                echo "\n--- \$service logs ---"
                                kubectl logs \$POD -n ${NAMESPACE} --tail=20 || true
                            fi
                        done
                    """
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    echo "Cleaning up ZAP scan jobs"
                    sh """
                        kubectl delete jobs -n ${NAMESPACE} -l app=zap-scanner --ignore-not-found=true || true
                    """
                    
                    echo "Cleaning up Helm releases and namespace ${NAMESPACE}"
                    sh """
                        helm uninstall config-server-${PREFIX_RELEASE} --namespace ${NAMESPACE} --ignore-not-found || true
                        helm uninstall customer-service-${PREFIX_RELEASE} --namespace ${NAMESPACE} --ignore-not-found || true
                        helm uninstall vets-service-${PREFIX_RELEASE} --namespace ${NAMESPACE} --ignore-not-found || true
                        helm uninstall visit-service-${PREFIX_RELEASE} --namespace ${NAMESPACE} --ignore-not-found || true
                        helm uninstall api-gateway-${PREFIX_RELEASE} --namespace ${NAMESPACE} --ignore-not-found || true
                        kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
                    """
                    echo "Helm releases uninstalled and namespace ${NAMESPACE} deleted"
                    
                    echo "Cleaning up Docker images with tag ${IMAGE_TAG}"
                    sh """
                        docker rmi ${DOCKER_REGISTRY}/spring-petclinic-config-server:${IMAGE_TAG} || true
                        docker rmi ${DOCKER_REGISTRY}/spring-petclinic-customers-service:${IMAGE_TAG} || true
                        docker rmi ${DOCKER_REGISTRY}/spring-petclinic-vets-service:${IMAGE_TAG} || true
                        docker rmi ${DOCKER_REGISTRY}/spring-petclinic-visits-service:${IMAGE_TAG} || true
                        docker rmi ${DOCKER_REGISTRY}/spring-petclinic-api-gateway:${IMAGE_TAG} || true
                        
                        echo "Cleaning up dangling images..."
                        docker image prune -f || true
                    """
                    echo "Docker images cleaned up"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Archiving ZAP reports..."
                archiveArtifacts artifacts: "${ZAP_REPORT_DIR}/**", allowEmptyArchive: true
                
                echo """
                ===============================================
                ZAP REPORTS ARCHIVED SUCCESSFULLY
                ===============================================
                Reports location: ${ZAP_REPORT_DIR}/
                
                Available reports:
                - zap-baseline-report.html (Baseline Scan)
                - zap-baseline-report.json (JSON format)
                - zap-baseline-report.md (Markdown format)
                - zap-active-report.html (Active Scan)
                - zap-active-report.json (JSON format)
                - zap-active-report.md (Markdown format)
                
                To view HTML reports:
                1. Go to Build Artifacts
                2. Download and open HTML files in browser
                ===============================================
                """
            }
        }
        success {
            echo "Pipeline completed successfully!"
            echo "Namespace: ${NAMESPACE}"
            echo "Image Tag: ${IMAGE_TAG}"
            echo "ZAP reports archived in ${ZAP_REPORT_DIR}/"
        }
        failure {
            echo "Pipeline failed!"
            echo "Attempting cleanup of Helm releases and namespace ${NAMESPACE}"
            sh """
                helm uninstall config-server --namespace ${NAMESPACE} --ignore-not-found || true
                helm uninstall customers-service --namespace ${NAMESPACE} --ignore-not-found || true
                helm uninstall vets-service --namespace ${NAMESPACE} --ignore-not-found || true
                helm uninstall visits-service --namespace ${NAMESPACE} --ignore-not-found || true
                kubectl delete namespace ${NAMESPACE} --ignore-not-found=true || true
            """
        }
    }
}