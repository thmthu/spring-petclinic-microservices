pipeline {
    agent {
        label 'host-node'
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
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
                            -e "s/\\.petclinic\\.svc\\.cluster\\.local/.${NAMESPACE}.svc.cluster.local/g" \
                            deployment-k8s/istio/virtualservice.yaml | kubectl apply -f -
                    """
                    
                    // Deploy DestinationRule
                    sh """
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
                            -e "s/\\*\\.petclinic\\.svc\\.cluster\\.local/*.${NAMESPACE}.svc.cluster.local/g" \
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
                        sed -e "s/namespace: petclinic/namespace: ${NAMESPACE}/g" \
                            -e "s/cluster\\.local\\/ns\\/petclinic\\//cluster.local\\/ns\\/${NAMESPACE}\\//g" \
                            deployment-k8s/istio/authorization-customer.yaml | kubectl apply -f -
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
        
        stage('Get Application URL') {
            steps {
                script {
                    echo "Getting Istio Ingress Gateway URL"
                   
                    
                    env.INGRESS_HOST = sh(
                        script: "kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.clusterIP}'",
                        returnStdout: true
                    ).trim()
                    
                    env.INGRESS_PORT = sh(
                        script: "kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name==\"http2\")].port}'",
                        returnStdout: true
                    ).trim()
                    
                    env.TARGET_URL = "http://${env.INGRESS_HOST}:${env.INGRESS_PORT}"
                    
                    echo "Target URL for ZAP scan: ${env.TARGET_URL}"
                    
                    // Test connectivity
                    sh """
                        echo "Testing connectivity to ${env.TARGET_URL}"
                        curl -v ${env.TARGET_URL} || echo "Failed to connect, but continuing..."
                    """
                }
            }
        }
        
        stage('OWASP ZAP Baseline Scan') {
            steps {
                script {
                    echo "Running OWASP ZAP Baseline Scan on ${env.TARGET_URL}"
                    sh """
                        # Create report directory and set permissions
                        mkdir -p ${ZAP_REPORT_DIR}
                        chmod 777 ${ZAP_REPORT_DIR}
                        
                        # Run ZAP baseline scan with proper user mapping
                        docker run --rm \
                            -v \${PWD}/${ZAP_REPORT_DIR}:/zap/wrk:rw \
                            -u zap \
                            --network host \
                            ghcr.io/zaproxy/zaproxy:${ZAP_VERSION} \
                            zap-baseline.py \
                            -t ${env.TARGET_URL} \
                            -r zap-baseline-report.html \
                            -J zap-baseline-report.json \
                            -w zap-baseline-report.md \
                            -I || true
                        
                        echo "ZAP Baseline Scan completed"
                        ls -lh ${ZAP_REPORT_DIR}/
                        
                        # Fix permissions for Jenkins to read (ignore errors if already readable)
                        sudo chmod -R 755 ${ZAP_REPORT_DIR} || true
                    """
                }
            }
        }
        
        stage('OWASP ZAP Active Scan') {
            steps {
                script {
                    echo "Running OWASP ZAP Active Scan on ${env.TARGET_URL}"
                    sh """
                        # Run ZAP full/active scan with proper user mapping
                        docker run --rm \
                            -v \${PWD}/${ZAP_REPORT_DIR}:/zap/wrk:rw \
                            -u zap \
                            --network host \
                            ghcr.io/zaproxy/zaproxy:${ZAP_VERSION} \
                            zap-full-scan.py \
                            -t ${env.TARGET_URL} \
                            -r zap-active-report.html \
                            -J zap-active-report.json \
                            -w zap-active-report.md \
                            -I || true
                        
                        echo "ZAP Active Scan completed"
                        ls -lh ${ZAP_REPORT_DIR}/
                        
                        # Fix permissions for Jenkins to read (ignore errors if already readable)
                        sudo chmod -R 755 ${ZAP_REPORT_DIR} || true
                    """
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
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
            echo "Target URL: ${env.TARGET_URL}"
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