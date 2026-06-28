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
                bat '"C:\\Program Files\\Python310\\python.exe" -m pip install pytest'
                bat '"C:\\Program Files\\Python310\\python.exe" -m pip install -r app/requirements.txt'
                bat '"C:\\Program Files\\Python310\\python.exe" -m pytest app/tests/'
            }
        }

        stage('SonarQube SAST') {
            steps {
                withSonarQubeEnv(SONARQUBE_ENV) {
                    script {
                        def scannerHome = tool 'SonarQube Scanner'
                        bat "\"${scannerHome}\\bin\\sonar-scanner.bat\" -Dsonar.projectKey=image-resizer -Dsonar.sources=app"
                    }
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials',
                                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        bat "aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %ECR_REPO%"
                        bat "docker build -t %ECR_REPO%:%IMAGE_TAG% ./app"
                        bat "docker push %ECR_REPO%:%IMAGE_TAG%"
                    }
                }
            }
        }

        stage('Terraform Deploy') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials',
                                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        bat 'terraform init -reconfigure'
                        bat "terraform apply -auto-approve -var=\"ecr_image_uri=%ECR_REPO%:%IMAGE_TAG%\""
                    }
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