pipeline {
    agent {
        label 'host-node'
    }
    environment {
        SONAR_TOKEN = credentials('sonar')
        SONAR_ORG = 'thmthu'
        SONAR_PROJECT_KEY = 'thmthu_spring-petclinic-microservices'
        SONAR_PROJECT_NAME = 'spring-petclinic-microservices'
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
        
        stage('Sonar Analysis') {
            steps {
                withSonarQubeEnv('sonarcloud') {
                    sh """
                        mvn sonar:sonar \
                        -Dsonar.organization=${SONAR_ORG} \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.projectName=${SONAR_PROJECT_NAME}
                    """
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }
    
    post {
        always {
            echo "SonarQube analysis completed"
        }
        success {
            echo "SonarQube quality gate passed"
        }
        failure {
            echo "SonarQube quality gate failed"
        }
    }
}
