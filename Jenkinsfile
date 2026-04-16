pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        IMAGE_NAME             = "${DOCKERHUB_CREDENTIALS_USR}/cw2-server"
        PROD_SERVER_IP         = credentials('prod-server-ip')
        SSH_KEY                = credentials('prod-server-ssh-key')
    }

    stages {

        // 3a — Triggered automatically by GitHub SCM polling / webhook
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // 3b — Build Docker image from Dockerfile in repo root
        stage('Build Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                sh "docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${IMAGE_NAME}:latest"
            }
        }

        // 3c — Build test: launch container and verify it starts
        stage('Build Test') {
            steps {
                sh """
                    docker run -d --name test-${BUILD_NUMBER} -p 8082:8081 ${IMAGE_NAME}:${BUILD_NUMBER}
                    sleep 5
                    docker exec test-${BUILD_NUMBER} node --version
                    CONTAINER_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' test-${BUILD_NUMBER})
                    curl -f http://\$CONTAINER_IP:8081 || exit 1
                """
            }
            post {
                always {
                    sh """
                        docker stop test-${BUILD_NUMBER} || true
                        docker rm   test-${BUILD_NUMBER} || true
                    """
                }
            }
        }

        // 3d — Push image to DockerHub
        stage('Push to DockerHub') {
            steps {
                sh "echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin"
                sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                sh "docker push ${IMAGE_NAME}:latest"
            }
        }

        // 3e — Rolling update on Kubernetes (no service disruption)
        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${PROD_SERVER_IP} \
                    'kubectl set image deployment/cw2-server cw2-server=${IMAGE_NAME}:${BUILD_NUMBER} && \
                     kubectl rollout status deployment/cw2-server'
                """
            }
        }
    }

    post {
        always {
            sh "docker logout || true"
        }
        success {
            echo "Pipeline succeeded — build ${BUILD_NUMBER} deployed to Kubernetes."
        }
        failure {
            echo "Pipeline failed at build ${BUILD_NUMBER}."
        }
    }
}