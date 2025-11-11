pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REPO = '987686461903.dkr.ecr.ap-south-1.amazonaws.com/multi-env-app'
    }

    stages {

        // ---------------------------
        // 1️⃣ CHECKOUT CODE
        // ---------------------------
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/sumanvitummala/multi-env-deploy.git'
            }
        }

        
        stage('Setup Tools') {
            steps {
                script {
                    sh '''
                    echo "🔧 Installing AWS CLI and Terraform if missing..."

                    # Install AWS CLI if not present
                    if ! command -v aws &> /dev/null; then
                    apt-get update -y && apt-get install -y awscli
                    fi

                    # Install Terraform if not present
                    if ! command -v terraform &> /dev/null; then
                    apt-get update -y && apt-get install -y curl unzip
                    curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o terraform.zip
                    unzip terraform.zip
                    mv terraform /usr/local/bin/
                    rm terraform.zip
                    fi

                    echo "✅ Terraform and AWS CLI setup complete"
                    terraform -version
                    aws --version
                    '''
                }
            }
        }


        // ---------------------------
        // 2️⃣ BUILD DOCKER IMAGE
        // ---------------------------
        stage('Build Docker Image') {
            steps {
                dir('app') {
                    script {
                        // Use default workspace if BRANCH_NAME not set (e.g., manual build)
                        def imageTag = env.BRANCH_NAME ?: "dev"

                        sh """
                        echo "🔧 Building Docker image for tag: ${imageTag}"
                        docker build -t ${ECR_REPO}:${imageTag} .
                        """
                    }
                }
            }
        }

        // ---------------------------
        // 3️⃣ PUSH TO AWS ECR
        // ---------------------------
        stage('Push to ECR') {
            steps {
                withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
                    script {
                        def imageTag = env.BRANCH_NAME ?: "dev"

                        sh """
                        echo "🔑 Logging in to ECR..."
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

                        echo "📦 Pushing image ${ECR_REPO}:${imageTag} ..."
                        docker push ${ECR_REPO}:${imageTag}
                        """
                    }
                }
            }
        }

        // ---------------------------
        // 4️⃣ DEPLOY VIA TERRAFORM
        // ---------------------------
        stage('Terraform Deploy') {
            steps {
                dir('terraform') {
                    withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
                        script {
                            def envName = env.BRANCH_NAME ?: "dev"
                            def eip = ""

                            // Map environment to EIP ID
                            if (envName == "dev") {
                                eip = "eipalloc-0e49f51837e220cf8"
                            } else if (envName == "qa") {
                                eip = "eipalloc-0107e1a2b50cb82b1"
                            } else if (envName == "main" || envName == "prod") {
                                eip = "eipalloc-0f6a1264a5e06e051"
                            } else {
                                error("Unknown environment: ${envName}")
                            }

                            sh """
                            echo "🚀 Initializing Terraform for ${envName}..."
                            terraform init -input=false

                            echo "🔁 Selecting or creating workspace..."
                            terraform workspace select ${envName} || terraform workspace new ${envName}

                            echo "🌍 Deploying environment: ${envName} with EIP ${eip}"
                            terraform apply -auto-approve -var "elastic_ip_allocation_id=${eip}"
                            """
                        }
                    }
                }
            }
        }
    }

    // ---------------------------
    // 5️⃣ POST-STAGE SUMMARY
    // ---------------------------
    post {
        success {
            echo "✅ Deployment successful for environment: ${env.BRANCH_NAME ?: 'dev'}"
        }
        failure {
            echo "❌ Deployment failed for environment: ${env.BRANCH_NAME ?: 'dev'}"
        }
    }
}

