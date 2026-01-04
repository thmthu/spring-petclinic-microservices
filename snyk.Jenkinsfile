pipeline {
    agent {
        label 'built-in'
    }
    tools {
        nodejs 'Node_23'
    }
    environment {
        SNYK_TOKEN = credentials('snyk-token')
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
                    echo "Note: Snyk test scans BOTH vulnerabilities AND licenses in one command"
                    
                    // Create report directory
                    sh "mkdir -p ${SNYK_REPORT_DIR}"
                    
                    // Run ONE scan that checks both vulnerabilities and licenses
                    // JSON format for detailed analysis
                    sh """
                        snyk test \
                            --all-projects \
                            --severity-threshold=low \
                            --json-file-output=${SNYK_REPORT_DIR}/snyk-results.json \
                            || true
                    """
                    
                    // Human-readable format for easy review
                    sh """
                        snyk test \
                            --all-projects \
                            --severity-threshold=low \
                            > ${SNYK_REPORT_DIR}/snyk-results.txt \
                            || true
                    """
                    
                    // Create a note about what was scanned
                    sh """
                        cat > ${SNYK_REPORT_DIR}/README.txt << 'READEOF'
Snyk Scan Results
=================

This scan checked:
✓ Security vulnerabilities (CVEs) in dependencies
✓ License compliance issues
✓ All Maven projects (--all-projects)
✓ All severity levels (low, medium, high, critical)

Files:
- snyk-results.json: Full detailed results in JSON format
- snyk-results.txt: Human-readable summary

The same 'snyk test' command scans BOTH vulnerabilities AND licenses.
There is no separate license-only command in Snyk CLI.

READEOF
                    """
                    
                    echo "Scan completed - checked vulnerabilities and licenses"
                }
            }
        }
        
        stage('Generate Summary Report') {
            steps {
                script {
                    echo "=== Generating Snyk Summary Report ==="
                    
                    // Create a summary markdown report
                    sh """
                        cat > ${SNYK_REPORT_DIR}/SNYK_SUMMARY.md << 'EOFSUM'
# Snyk Security Scan Report

## Scan Information
- **Date**: \$(date)
- **Project**: spring-petclinic-microservices
- **Branch**: ${env.BRANCH_NAME}
- **Build**: ${env.BUILD_NUMBER}

## Reports Generated

### 1. Security & License Scan
- **File**: snyk-results.json (Detailed JSON format)
- **File**: snyk-results.txt (Human-readable summary)
- **Content**: 
  - Security vulnerabilities (CVEs) with severity levels
  - License compliance issues for all dependencies
  - Upgrade paths and fix recommendations
- **Note**: One snyk test command scans both security and licenses

## How to Review Reports

1. **Download Artifacts**: Go to Jenkins Build Artifacts and download the snyk-reports folder
2. **View JSON Reports**: Use any JSON viewer or jq for detailed analysis
3. **View Text Reports**: Open .txt files for human-readable summary

## Vulnerability Severity Levels
- **Critical**: Immediate action required
- **High**: Should be fixed as soon as possible
- **Medium**: Should be fixed in near future
- **Low**: Consider fixing when convenient

## Next Steps
1. Review all identified vulnerabilities
2. Prioritize fixes based on severity
3. Update dependencies to patched versions
4. Re-run scan to verify fixes

EOFSUM
                    """
                    
                    // Display quick summary
                    sh """
                        echo "=========================================="
                        echo "SNYK SCAN SUMMARY"
                        echo "=========================================="
                        ls -lh ${SNYK_REPORT_DIR}/
                        echo "=========================================="
                        echo "Reports saved to: ${SNYK_REPORT_DIR}/"
                        echo "All reports are available as Jenkins artifacts"
                        echo "=========================================="
                    """
                }
            }
        }
        
        stage('Analyze Results') {
            steps {
                script {
                    echo "=== Analyzing Snyk Results ==="
                    
                    // Check if vulnerability report exists and show summary
                    sh """
                        if [ -f ${SNYK_REPORT_DIR}/snyk-results.txt ]; then
                            echo "=== SCAN RESULTS PREVIEW ==="
                            head -100 ${SNYK_REPORT_DIR}/snyk-results.txt || true
                            echo ""
                            echo "=== END OF PREVIEW ==="
                            echo "Download full report from Jenkins artifacts"
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
                
                // Archive all reports as Jenkins artifacts
                archiveArtifacts artifacts: "${SNYK_REPORT_DIR}/**", allowEmptyArchive: true
                
                echo """
                ===============================================
                SNYK SECURITY SCAN COMPLETED
                ===============================================
                
                Reports have been generated and archived:
                - Vulnerability scan results
                - License compliance results
                
                To access reports:
                1. Go to Jenkins Build Artifacts
                2. Download ${SNYK_REPORT_DIR} folder
                3. Review JSON and TXT files
                
                ===============================================
                """
            }
        }
        success {
            echo "✓ Snyk scan completed successfully"
            echo "✓ All reports generated and archived"
        }
        failure {
            echo "✗ Snyk scan encountered issues"
            echo "✓ Reports still generated for analysis"
            echo "→ Review artifacts to identify and fix vulnerabilities"
        }
    }
}
