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
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-config-server:${IMAGE_TAG}
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-customers-service:${IMAGE_TAG}
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-vets-service:${IMAGE_TAG}
                            docker push ${DOCKER_REGISTRY}/spring-petclinic-visits-service:${IMAGE_TAG}
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
        
        stage('Create Namespace') {
            steps {
                script {
                    echo "Creating namespace ${NAMESPACE}"
                    sh """
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
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
                                helm upgrade --install customers-service-${PREFIX_RELEASE} deployment-k8s/service-customer \
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
                                helm upgrade --install visits-service-${PREFIX_RELEASE} deployment-k8s/service-visit \
                                    --namespace ${NAMESPACE} \
                                    --set visits.image.tag=${IMAGE_TAG} 
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
        
        // stage('Cleanup') {
        //     steps {
        //         script {
        //             echo "Cleaning up Helm releases and namespace ${NAMESPACE}"
        //             sh """
        //                 helm uninstall config-server --namespace ${NAMESPACE} --ignore-not-found || true
        //                 helm uninstall customers-service --namespace ${NAMESPACE} --ignore-not-found || true
        //                 helm uninstall vets-service --namespace ${NAMESPACE} --ignore-not-found || true
        //                 helm uninstall visits-service --namespace ${NAMESPACE} --ignore-not-found || true
        //                 kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
        //             """
        //             echo "Helm releases uninstalled and namespace ${NAMESPACE} deleted"
        //         }
        //     }
        // }
    }
    
    post {
        success {
            echo "Pipeline completed successfully!"
            echo "Namespace: ${NAMESPACE}"
            echo "Image Tag: ${IMAGE_TAG}"
            echo "All resources have been cleaned up"
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