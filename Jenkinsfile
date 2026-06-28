pipeline {
    agent any
    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REPO = '848269788405.dkr.ecr.ap-south-1.amazonaws.com/image-resizer-lambda'
        IMAGE_TAG = "v1.${BUILD_NUMBER}"
        SONARQUBE_ENV = 'SonarQube'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Unit Test') {
            steps {
                bat 'pip install -r app/requirements.txt'
                bat 'python -m pytest app/tests/'
            }
        }

        stage('SonarQube SAST') {
            steps {
                withSonarQubeEnv(SONARQUBE_ENV) {
                    bat 'sonar-scanner -Dsonar.projectKey=image-resizer -Dsonar.sources=app'
                }
            }
        }

        stage('Get ECR Repo') {
            steps {
                script {
                    ECR_REPO = bat(
                        script: 'terraform -chdir=terraform output -raw ecr_repo_url',
                        returnStdout: true
                    ).trim().readLines().last()
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    bat "aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %ECR_REPO%"
                    bat "docker build -t %ECR_REPO%:%IMAGE_TAG% ./app"
                    bat "docker push %ECR_REPO%:%IMAGE_TAG%"
                }
            }
        }

        stage('Terraform Deploy') {
            steps {
                dir('terraform') {
                    bat 'terraform init'
                    bat "terraform apply -auto-approve -var=\"ecr_image_uri=%ECR_REPO%:%IMAGE_TAG%\""
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