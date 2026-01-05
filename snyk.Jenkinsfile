pipeline {
    agent {
        label 'built-in'
    }
    tools {
        nodejs 'Node_23'
    }
    environment {
        SNYK_TOKEN = credentials('thmthu-snyk')
        SNYK_REPORT_DIR = "snyk-reports"
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
        
        stage('Snyk Authentication') {
            steps {
                echo "Authenticating with Snyk..."
                sh 'snyk auth $SNYK_TOKEN'
            }
        }
        
        stage('Snyk Vulnerability & License Scan') {
            steps {
                script {
                    echo "=== Running Snyk Security Scan ==="
                    sh "mkdir -p ${SNYK_REPORT_DIR}"
                    
                    // Xuất file JSON để phân tích chi tiết
                    sh """
                        snyk test \
                            --all-projects \
                            --severity-threshold=low \
                            --json-file-output=${SNYK_REPORT_DIR}/snyk-results.json \
                            || true
                    """
                    
                    // Xuất file TXT để người dùng dễ đọc trực tiếp
                    sh """
                        snyk test \
                            --all-projects \
                            --severity-threshold=low \
                            > ${SNYK_REPORT_DIR}/snyk-results.txt \
                            || true
                    """
                    
                    echo "Scan completed - checked vulnerabilities and licenses"
                }
            }
        }

        stage('Snyk Monitor') {
            steps {
                script {
                    echo "=== Sending Project Snapshot to Snyk Dashboard ==="
                    sh 'snyk monitor --all-projects'
                    echo "✓ Snapshot sent! You can now see the project on your Snyk UI."
                }
            }
        }

        stage('Analyze Results') {
            steps {
                script {
                    echo "=== Analyzing Snyk Results ==="
                    sh """
                        if [ -f ${SNYK_REPORT_DIR}/snyk-results.txt ]; then
                            echo "=== SCAN RESULTS PREVIEW ==="
                            head -50 ${SNYK_REPORT_DIR}/snyk-results.txt || true
                            echo "=== END OF PREVIEW ==="
                        fi
                    """
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "=== Archiving Snyk Reports ==="
                archiveArtifacts artifacts: "${SNYK_REPORT_DIR}/**", allowEmptyArchive: true
            }
        }
        success {
            echo "✓ Snyk scan completed successfully. Reports archived."
        }
        failure {
            echo "✗ Snyk scan encountered issues. Check artifacts for details."
        }
    }
}