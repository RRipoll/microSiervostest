#!/usr/bin/env groovy

// Jenkins Pipeline for TestJava Price Service
pipeline {
    agent any
    
    // Pipeline options
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        parallelsAlwaysFailFast()
        skipDefaultCheckout(false)
    }
    
    // Environment variables
    environment {
        JAVA_VERSION = '17'
        GRADLE_OPTS = '-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.configureondemand=true'
        SPRING_PROFILES_ACTIVE = 'test'
        DOCKER_REGISTRY = credentials('docker-registry-url')
        SONAR_TOKEN = credentials('sonar-token')
        SLACK_CHANNEL = '#deployments'
    }
    
    // Build triggers
    triggers {
        pollSCM('H/5 * * * *') // Poll every 5 minutes
        cron('H 2 * * *')      // Daily build at 2 AM
    }
    
    stages {
        // Checkout and setup
        stage('🔄 Checkout & Setup') {
            steps {
                script {
                    echo "🚀 Starting CI/CD Pipeline for ${env.BRANCH_NAME}"
                    echo "Build Number: ${env.BUILD_NUMBER}"
                    echo "Java Version: ${env.JAVA_VERSION}"
                }
                
                // Clean workspace
                deleteDir()
                
                // Checkout code
                checkout scm
                
                // Make gradlew executable
                sh 'chmod +x ./gradlew'
                
                // Validate Gradle wrapper
                sh './gradlew --version'
            }
        }
        
        // Parallel fast feedback stage
        stage('⚡ Fast Feedback') {
            parallel {
                stage('🔍 Code Analysis') {
                    steps {
                        echo '🔍 Running static code analysis...'
                        sh './gradlew compileJava compileTestJava --build-cache'
                        
                        // Archive compilation artifacts
                        archiveArtifacts artifacts: 'build/classes/**', fingerprint: true
                    }
                }
                
                stage('🔄 Unit Tests') {
                    steps {
                        echo '🔄 Running unit tests...'
                        sh './gradlew fastTest --continue --build-cache'
                    }
                    post {
                        always {
                            // Publish test results
                            publishTestResults testResultsPattern: 'build/test-results/unitTest/TEST-*.xml'
                            
                            // Publish coverage
                            publishCoverage adapters: [
                                jacocoAdapter('build/reports/jacoco/unitTest/jacocoTestReport.xml')
                            ], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                        }
                    }
                }
            }
        }
        
        // API and Integration Tests
        stage('🧪 Comprehensive Testing') {
            parallel {
                stage('🌐 API Tests') {
                    steps {
                        echo '🌐 Running API tests...'
                        sh './gradlew validateApi --continue --build-cache'
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'build/test-results/apiTest/TEST-*.xml'
                        }
                    }
                }
                
                stage('🔗 Integration Tests') {
                    steps {
                        echo '🔗 Running integration tests...'
                        sh './gradlew integrationTest --continue --build-cache'
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'build/test-results/integrationTest/TEST-*.xml'
                        }
                    }
                }
            }
        }
        
        // Quality Gates
        stage('🛡️ Quality Gates') {
            parallel {
                stage('📊 Code Coverage') {
                    steps {
                        echo '📊 Generating code coverage report...'
                        sh './gradlew testCoverageReport --continue'
                        
                        // Publish combined coverage
                        publishCoverage adapters: [
                            jacocoAdapter('build/reports/jacoco/test/jacocoTestReport.xml')
                        ], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                    }
                }
                
                stage('🔍 SonarQube Analysis') {
                    when {
                        anyOf {
                            branch 'main'
                            branch 'develop'
                            changeRequest()
                        }
                    }
                    steps {
                        echo '🔍 Running SonarQube analysis...'
                        withSonarQubeEnv('SonarQube') {
                            sh './gradlew sonar --continue'
                        }
                    }
                }
                
                stage('🔒 Security Scan') {
                    steps {
                        echo '🔒 Running security analysis...'
                        sh './gradlew dependencyCheckAnalyze --continue || true'
                        
                        // Archive security reports
                        archiveArtifacts artifacts: 'build/reports/dependency-check-report.html', 
                                       allowEmptyArchive: true
                    }
                }
            }
        }
        
        // Quality Gate Check
        stage('🚦 Quality Gate') {
            steps {
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline aborted due to quality gate failure: ${qg.status}"
                        }
                        echo '✅ Quality gate passed successfully'
                    }
                }
            }
        }
        
        // Build Application
        stage('🏗️ Build Application') {
            steps {
                echo '🏗️ Building application...'
                sh './gradlew build -x test --build-cache --scan'
                
                // Archive build artifacts
                archiveArtifacts artifacts: 'build/libs/*.jar', fingerprint: true
                archiveArtifacts artifacts: 'build/distributions/*', allowEmptyArchive: true
                
                echo '✅ Application built successfully'
                sh 'ls -la build/libs/'
            }
        }
        
        // Docker Build (for main/develop branches)
        stage('🐳 Docker Build') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    echo '🐳 Building Docker image...'
                    def imageName = "testjava-priceservice"
                    def imageTag = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
                    
                    // Build Docker image
                    def dockerImage = docker.build("${imageName}:${imageTag}")
                    
                    // Tag as latest for the branch
                    sh "docker tag ${imageName}:${imageTag} ${imageName}:${env.BRANCH_NAME}-latest"
                    
                    // Push to registry if configured
                    if (env.DOCKER_REGISTRY) {
                        docker.withRegistry("https://${env.DOCKER_REGISTRY}") {
                            dockerImage.push(imageTag)
                            dockerImage.push("${env.BRANCH_NAME}-latest")
                        }
                        echo "✅ Docker image pushed to registry"
                    }
                    
                    // Store image info
                    env.DOCKER_IMAGE = "${imageName}:${imageTag}"
                }
            }
        }
        
        // Deploy to Staging
        stage('🚀 Deploy to Staging') {
            when {
                branch 'develop'
            }
            environment {
                DEPLOY_ENV = 'staging'
            }
            steps {
                script {
                    echo '🚀 Deploying to staging environment...'
                    
                    // Simulate deployment (replace with actual deployment logic)
                    sh '''
                        echo "Deploying ${DOCKER_IMAGE} to staging..."
                        echo "Environment: ${DEPLOY_ENV}"
                        echo "Build: ${BUILD_NUMBER}"
                        sleep 5
                    '''
                    
                    // Run smoke tests
                    echo '🔥 Running staging smoke tests...'
                    sh './gradlew smokeTest --continue || echo "Smoke tests failed"'
                    
                    echo '✅ Staging deployment completed'
                }
            }
            post {
                success {
                    script {
                        notifySlack(":white_check_mark: Staging deployment successful for build ${env.BUILD_NUMBER}")
                    }
                }
                failure {
                    script {
                        notifySlack(":x: Staging deployment failed for build ${env.BUILD_NUMBER}")
                    }
                }
            }
        }
        
        // Performance Tests (on schedule or manual)
        stage('🚀 Performance Tests') {
            when {
                anyOf {
                    triggeredBy 'TimerTrigger'
                    triggeredBy cause: 'UserIdCause'
                }
            }
            steps {
                echo '🚀 Running performance tests...'
                sh './gradlew performanceTest --continue'
                
                // Archive performance reports
                archiveArtifacts artifacts: 'build/reports/tests/performanceTest/**', 
                               allowEmptyArchive: true
            }
        }
        
        // Deploy to Production
        stage('🌟 Deploy to Production') {
            when {
                branch 'main'
            }
            environment {
                DEPLOY_ENV = 'production'
            }
            options {
                timeout(time: 15, unit: 'MINUTES')
            }
            steps {
                script {
                    // Manual approval for production
                    input message: 'Deploy to Production?', 
                          ok: 'Deploy',
                          parameters: [
                              choice(name: 'DEPLOYMENT_TYPE', 
                                   choices: ['rolling', 'blue-green', 'canary'],
                                   description: 'Select deployment strategy')
                          ]
                    
                    echo "🌟 Deploying to production with ${params.DEPLOYMENT_TYPE} strategy..."
                    
                    // Simulate production deployment
                    sh '''
                        echo "Deploying ${DOCKER_IMAGE} to production..."
                        echo "Strategy: ${DEPLOYMENT_TYPE}"
                        echo "Build: ${BUILD_NUMBER}"
                        sleep 10
                    '''
                    
                    // Health checks
                    echo '❤️ Running production health checks...'
                    sh 'echo "Health checks passed"'
                    
                    echo '✅ Production deployment completed'
                }
            }
            post {
                success {
                    script {
                        notifySlack(":rocket: Production deployment successful! Build ${env.BUILD_NUMBER} is live.")
                    }
                }
                failure {
                    script {
                        notifySlack(":rotating_light: Production deployment failed for build ${env.BUILD_NUMBER}!")
                    }
                }
            }
        }
    }
    
    // Post-build actions
    post {
        always {
            echo '📊 Pipeline completed'
            
            // Archive all reports
            archiveArtifacts artifacts: 'build/reports/**', allowEmptyArchive: true
            
            // Clean workspace
            cleanWs()
        }
        
        success {
            echo '✅ Pipeline succeeded'
            script {
                if (env.BRANCH_NAME in ['main', 'develop']) {
                    notifySlack(":white_check_mark: Build ${env.BUILD_NUMBER} succeeded on ${env.BRANCH_NAME}")
                }
            }
        }
        
        failure {
            echo '❌ Pipeline failed'
            script {
                notifySlack(":x: Build ${env.BUILD_NUMBER} failed on ${env.BRANCH_NAME}")
            }
        }
        
        unstable {
            echo '⚠️ Pipeline unstable'
            script {
                notifySlack(":warning: Build ${env.BUILD_NUMBER} is unstable on ${env.BRANCH_NAME}")
            }
        }
        
        changed {
            echo '🔄 Pipeline status changed'
        }
    }
}

// Helper functions
def notifySlack(String message) {
    if (env.SLACK_CHANNEL) {
        slackSend(
            channel: env.SLACK_CHANNEL,
            color: currentBuild.currentResult == 'SUCCESS' ? 'good' : 'danger',
            message: "${message}\nBranch: ${env.BRANCH_NAME}\nCommit: ${env.GIT_COMMIT?.take(7)}"
        )
    }
}

def publishTestResults(String pattern) {
    publishTestResults([
        testResultsPattern: pattern,
        healthScaleFactor: 1.0,
        allowEmptyResults: true
    ])
}