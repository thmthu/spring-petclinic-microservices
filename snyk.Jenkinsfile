pipeline {
    agent {
        label 'host-node'
    }
    tools {
        nodejs 'Node_23'
    }
    environment {
        SNYK_TOKEN = credentials('snyk-token')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code..."
                checkout scm
            }
        }
        
        stage('Install Snyk CLI') {
            steps {
                sh 'npm install -g snyk'
            }
        }
        
        stage('Snyk Dependency Scan') {
            steps {
                sh '''
                    snyk auth $SNYK_TOKEN
                    snyk test --severity-threshold=high
                '''
            }
        }
    }
    
    post {
        always {
            echo "Snyk scan completed"
        }
        success {
            echo "Snyk scan passed successfully"
        }
        failure {
            echo "Snyk scan failed - vulnerabilities found"
        }
    }
}
