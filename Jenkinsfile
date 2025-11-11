pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REPO = '987686461903.dkr.ecr.ap-south-1.amazonaws.com/multi-env-app'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git url: 'https://github.com/sumanvitummala/multi-env-deploy.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('app') {
                    script {
                        sh '''
                        docker build -t multi-env-app:${BRANCH_NAME} .
                        '''
                    }
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
                    script {
                        sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
                        docker tag multi-env-app:${BRANCH_NAME} ${ECR_REPO}:${BRANCH_NAME}
                        docker push ${ECR_REPO}:${BRANCH_NAME}
                        '''
                    }
                }
            }
        }

        stage('Terraform Deploy') {
            steps {
                dir('terraform') {
                    withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
                        script {
                            sh '''
                            terraform init
                            terraform workspace select ${BRANCH_NAME} || terraform workspace new ${BRANCH_NAME}

                            if [ "${BRANCH_NAME}" == "dev" ]; then
                              terraform apply -auto-approve -var "elastic_ip_allocation_id=eipalloc-0e49f51837e220cf8"
                            elif [ "${BRANCH_NAME}" == "qa" ]; then
                              terraform apply -auto-approve -var "elastic_ip_allocation_id=eipalloc-0107e1a2b50cb82b1"
                            elif [ "${BRANCH_NAME}" == "main" ]; then
                              terraform apply -auto-approve -var "elastic_ip_allocation_id=eipalloc-0f6a1264a5e06e051"
                            fi
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployment successful for ${BRANCH_NAME}"
        }
        failure {
            echo "❌ Deployment failed for ${BRANCH_NAME}"
        }
    }
}
