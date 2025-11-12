pipeline {
    agent any

    parameters {
        choice(name: 'ENV', choices: ['dev', 'qa', 'prod'], description: 'Select environment to deploy')
    }

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

        // ---------------------------
        // 2️⃣ BUILD DOCKER IMAGE
        // ---------------------------
        stage('Build Docker Image') {
            steps {
                dir('app') {
                    script {
                        def imageTag = params.ENV
                        bat """
                        echo 🔧 Building Docker image for tag: ${imageTag}
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
                withAWS(credentials: 'aws-access', region: "${AWS_REGION}") {
                    script {
                        def imageTag = params.ENV
                        bat """
                        echo 🔑 Logging in to ECR...
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

                        echo 📦 Pushing image ${ECR_REPO}:${imageTag} ...
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
                    withAWS(credentials: 'aws-access', region: "${AWS_REGION}") {
                        script {
                            def envName = params.ENV
                            def eip = ""

                            if (envName == "dev") {
                                eip = "eipalloc-0af979e1817cff367"
                            } else if (envName == "qa") {
                                eip = "eipalloc-0b7d0b942d296f987"
                            } else if (envName == "prod") {
                                eip = "eipalloc-0f6a1264a5e06e051"
                            } else {
                                error("❌ Unknown environment: ${envName}")
                            }

                            bat """
                            echo 🚀 Initializing Terraform for ${envName}...
                            terraform init -input=false

                            echo 🔁 Selecting or creating workspace...
                            terraform workspace select ${envName} || terraform workspace new ${envName}

                            echo 🌍 Deploying environment: ${envName} with EIP ${eip}
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
            echo "✅ Deployment successful for environment: ${params.ENV}"
        }
        failure {
            echo "❌ Deployment failed for environment: ${params.ENV}"
        }
    }
}
