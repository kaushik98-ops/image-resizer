pipeline {
    agent any
    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REPO = '' // Will be set after terraform
        IMAGE_TAG = "v1.${BUILD_NUMBER}"
        SONARQUBE_ENV = 'SonarQube' // Name of SonarQube server in Jenkins
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Unit Test') {
            steps {
                sh 'pip install -r app/requirements.txt'
                sh 'pytest app/tests/' // Add tests later
            }
        }
        
        stage('SonarQube SAST') {
            steps {
                withSonarQubeEnv(SONARQUBE_ENV) {
                    sh 'sonar-scanner -Dsonar.projectKey=image-resizer -Dsonar.sources=app'
                }
            }
        }
        
        stage('Get ECR Repo') {
            steps {
                script {
                    // Run terraform output to get ECR URL. Assumes terraform init already done
                    ECR_REPO = sh(script: 'terraform -chdir=terraform output -raw ecr_repo_url', returnStdout: true).trim()
                }
            }
        }
        
        stage('Docker Build & Push') {
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}"
                    sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ./app"
                    sh "docker push ${ECR_REPO}:${IMAGE_TAG}"
                }
            }
        }
        
        stage('Terraform Deploy') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    sh "terraform apply -auto-approve -var='ecr_image_uri=${ECR_REPO}:${IMAGE_TAG}'"
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}