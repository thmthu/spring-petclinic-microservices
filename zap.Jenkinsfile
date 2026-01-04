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
        
        stage('ZAP Security Scans') {
            stages {
                stage('Setup ZAP Scanner') {
                    steps {
                        script {
                            echo "Deploying ZAP scanner service account"
                            sh """
                                sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \\
                                    deployment-k8s/dast-zap/serviceaccount.yaml | kubectl apply -f -
                            """
                        }
                    }
                }
                
                stage('Deploy All Baseline Scans') {
                    steps {
                        script {
                            echo "Deploying ZAP Baseline Scan (all services)"
                            sh """
                                cat deployment-k8s/dast-zap/dast-zap.yaml | \\
                                sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" | \\
                                awk 'BEGIN{RS="---"} /scan-type: baseline/{print "---"; print}' | \\
                                kubectl apply -n ${NAMESPACE} -f -
                                
                                echo "\\nBaseline scan job deployed:"
                                kubectl get jobs -n ${NAMESPACE} -l scan-type=baseline
                            """
                        }
                    }
                }
                
                stage('Wait for Baseline Scans') {
                    steps {
                        script {
                            echo "Waiting for Baseline Scan to complete..."
                            sh """
                                echo "Waiting for zap-baseline-scan-all..."
                                kubectl wait --for=condition=complete job/zap-baseline-scan-all \\
                                    -n ${NAMESPACE} --timeout=900s || true
                                
                                echo "\\nBaseline scan job status:"
                                kubectl get jobs -n ${NAMESPACE} -l scan-type=baseline
                                
                                echo "\\nPod logs:"
                                kubectl logs -n ${NAMESPACE} -l app=zap-scanner,scan-type=baseline --tail=50
                            """
                        }
                    }
                }
                
                stage('Retrieve Baseline Reports') {
                    steps {
                        script {
                            echo "Retrieving Baseline scan reports"
                            sh """
                                mkdir -p \${ZAP_REPORT_DIR}/baseline
                                
                                echo "Waiting for baseline scan job to have a pod..."
                                sleep 5
                                
                                echo "Finding baseline scan pod..."
                                POD=\$(kubectl get pods -n \${NAMESPACE} -l app=zap-scanner,scan-type=baseline --field-selector=status.phase!=Failed --no-headers -o custom-columns=:metadata.name 2>/dev/null | head -1)
                                
                                if [ -n "\$POD" ]; then
                                    echo "Copying reports from pod: \$POD"
                                    kubectl cp \${NAMESPACE}/\$POD:/zap/wrk/ \${ZAP_REPORT_DIR}/baseline/ 2>/dev/null || echo "Warning: Failed to copy some files"
                                else
                                    echo "ERROR: No baseline scan pod found"
                                    exit 1
                                fi
                                
                                echo "\\nBaseline reports retrieved:"
                                ls -lh \${ZAP_REPORT_DIR}/baseline/ || echo "No reports found"
                            """
                        }
                    }
                }
                
                stage('Deploy All Active Scans') {
                    steps {
                        script {
                            echo "Deploying ZAP Active Scan (all services)"
                            sh """
                                cat deployment-k8s/dast-zap/dast-zap.yaml | \\
                                sed "s/namespace: petclinic/namespace: ${NAMESPACE}/g" | \\
                                awk 'BEGIN{RS="---"} /scan-type: active/{print "---"; print}' | \\
                                kubectl apply -n ${NAMESPACE} -f -
                                
                                echo "\\nActive scan job deployed:"
                                kubectl get jobs -n ${NAMESPACE} -l scan-type=active
                            """
                        }
                    }
                }
                
                stage('Wait for Active Scans') {
                    steps {
                        script {
                            echo "Waiting for Active Scan to complete..."
                            sh """
                                echo "Waiting for zap-active-scan-all..."
                                kubectl wait --for=condition=complete job/zap-active-scan-all \\
                                    -n ${NAMESPACE} --timeout=1800s || true
                                
                                echo "\\nActive scan job status:"
                                kubectl get jobs -n ${NAMESPACE} -l scan-type=active
                                
                                echo "\\nPod logs:"
                                kubectl logs -n ${NAMESPACE} -l app=zap-scanner,scan-type=active --tail=50
                            """
                        }
                    }
                }
                
                stage('Retrieve Active Reports') {
                    steps {
                        script {
                            echo "Retrieving Active scan reports"
                            sh """
                                mkdir -p \${ZAP_REPORT_DIR}/active
                                
                                echo "Waiting for active scan job to have a pod..."
                                sleep 5
                                
                                echo "Finding active scan pod..."
                                POD=\$(kubectl get pods -n \${NAMESPACE} -l app=zap-scanner,scan-type=active --field-selector=status.phase!=Failed --no-headers -o custom-columns=:metadata.name 2>/dev/null | head -1)
                                
                                if [ -n "\$POD" ]; then
                                    echo "Copying reports from pod: \$POD"
                                    kubectl cp \${NAMESPACE}/\$POD:/zap/wrk/ \${ZAP_REPORT_DIR}/active/ 2>/dev/null || echo "Warning: Failed to copy some files"
                                else
                                    echo "ERROR: No active scan pod found"
                                    exit 1
                                fi
                                
                                echo "\\nActive reports retrieved:"
                                ls -lh \${ZAP_REPORT_DIR}/active/ || echo "No reports found"
                            """
                        }
                    }
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
                echo "Archiving ZAP scan reports..."
                
                // Archive all ZAP reports as artifacts
                archiveArtifacts artifacts: "${ZAP_REPORT_DIR}/**/*", 
                                 allowEmptyArchive: true,
                                 fingerprint: true
                
                // Publish HTML reports
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: "${ZAP_REPORT_DIR}/baseline",
                    reportFiles: 'zap-baseline-report.html',
                    reportName: 'ZAP Baseline Scan Report',
                    reportTitles: 'ZAP Baseline Scan'
                ])
                
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: "${ZAP_REPORT_DIR}/active",
                    reportFiles: 'zap-active-report.html',
                    reportName: 'ZAP Active Scan Report',
                    reportTitles: 'ZAP Active Scan'
                ])
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