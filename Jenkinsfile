pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        IMAGE_NAME             = "${DOCKERHUB_CREDENTIALS_USR}/cw2-server"
        PROD_SERVER_IP         = credentials('prod-server-ip')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                sh "docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${IMAGE_NAME}:latest"
            }
        }

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

        stage('Push to DockerHub') {
            steps {
                sh "echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin"
                sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                sh "docker push ${IMAGE_NAME}:latest"
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sshagent(credentials: ['prod-server-ssh-key']) {
                    script {
                        // Build the remote command as a Groovy variable first —
                        // this lets Groovy interpolate IMAGE_NAME and BUILD_NUMBER,
                        // then we pass it to SSH wrapped in single quotes so the
                        // shell never re-interprets the &&
                        def remoteCmd = "/usr/local/bin/kubectl set image deployment/cw2-server cw2-server=${IMAGE_NAME}:${BUILD_NUMBER} && /usr/local/bin/kubectl rollout status deployment/cw2-server"

                        echo "=== Deploy debug ==="
                        echo "PROD_SERVER_IP: ${PROD_SERVER_IP}"
                        echo "Remote command: ${remoteCmd}"

                        sh "ssh -o StrictHostKeyChecking=no ubuntu@${PROD_SERVER_IP} '${remoteCmd}'"
                    }
                }
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