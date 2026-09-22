#!groovy

pipeline {

    agent { label 'Agent001' }

    environment {

        IMAGE_NAME_FRONT = "alonaarz/tiktok_clone_front"
        IMAGE_NAME_BACK = "alonaarz/tiktok_clone_back"
        IMAGE_NAME_VIDEO_PROCESSOR = "alonaarz/tiktok_clone_video_processor"

        COMPOSE_FILE = "compose.local.yaml"
    }

    stages {

        // ====================================================
        // CHECKOUT
        // ====================================================

        stage("Checkout") {

            steps {

                echo "=============================================="
                echo "Checking out develop branch"
                echo "=============================================="

                checkout scm
            }
        }


        // ====================================================
        // GET SERVER IP
        // ====================================================

        stage("Prepare environment") {

            steps {

                sh '''
                    set -e

                    cd "${WORKSPACE}"

                    CURRENT_IP=$(curl -s https://ifconfig.me)

                    echo "=============================================="
                    echo "Current public IP: ${CURRENT_IP}"
                    echo "=============================================="

                    echo "${CURRENT_IP}" > .current_ip
                '''
            }
        }


        // ====================================================
        // BUILD FRONTEND
        // ====================================================

        stage("Build Frontend image") {

            steps {

                withCredentials([
                    string(
                        credentialsId: 'google-client-id',
                        variable: 'GOOGLE_CLIENT_ID'
                    )
                ]) {

                    sh '''
                        set -e

                        cd "${WORKSPACE}"

                        CURRENT_IP=$(cat .current_ip)

                        echo "=============================================="
                        echo "Building FRONTEND image"
                        echo "API URL: http://${CURRENT_IP}:8080"
                        echo "=============================================="

                        docker build \
                          --build-arg NGINX_ENV=local \
                          --build-arg VITE_GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
                          --build-arg VITE_API_BASE_URL="http://${CURRENT_IP}:8080" \
                          -t "${IMAGE_NAME_FRONT}:${BUILD_NUMBER}" \
                          -t "${IMAGE_NAME_FRONT}:latest" \
                          -f front/Dockerfile \
                          front/
                    '''
                }
            }
        }


        // ====================================================
        // BUILD BACKEND
        // ====================================================

        stage("Build Backend image") {

            steps {

                sh '''
                    set -e

                    cd "${WORKSPACE}"

                    echo "=============================================="
                    echo "Building BACKEND image"
                    echo "=============================================="

                    docker build \
                      -t "${IMAGE_NAME_BACK}:${BUILD_NUMBER}" \
                      -t "${IMAGE_NAME_BACK}:latest" \
                      -f back/.dockerfile \
                      back/
                '''
            }
        }


        // ====================================================
        // BUILD VIDEO PROCESSOR
        // ====================================================

        stage("Build Video Processor image") {

            steps {

                sh '''
                    set -e

                    cd "${WORKSPACE}"

                    echo "=============================================="
                    echo "Building VIDEO PROCESSOR image"
                    echo "=============================================="

                    docker build \
                      -t "${IMAGE_NAME_VIDEO_PROCESSOR}:${BUILD_NUMBER}" \
                      -t "${IMAGE_NAME_VIDEO_PROCESSOR}:latest" \
                      -f back/VideoProcessor/.dockerfile \
                      back/
                '''
            }
        }


        // ====================================================
        // DOCKER HUB LOGIN
        // ====================================================

        stage("Docker Hub login") {

            steps {

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "${DOCKERHUB_PASSWORD}" | \
                          docker login \
                            -u "${DOCKERHUB_USERNAME}" \
                            --password-stdin
                    '''
                }
            }
        }


        // ====================================================
        // PUSH IMAGES
        // ====================================================

        stage("Push images to Docker Hub") {

            steps {

                sh '''
                    set -e

                    echo "=============================================="
                    echo "Pushing images to Docker Hub"
                    echo "=============================================="

                    docker push "${IMAGE_NAME_FRONT}:${BUILD_NUMBER}"
                    docker push "${IMAGE_NAME_FRONT}:latest"

                    docker push "${IMAGE_NAME_BACK}:${BUILD_NUMBER}"
                    docker push "${IMAGE_NAME_BACK}:latest"

                    docker push "${IMAGE_NAME_VIDEO_PROCESSOR}:${BUILD_NUMBER}"
                    docker push "${IMAGE_NAME_VIDEO_PROCESSOR}:latest"
                '''
            }
        }


        // ====================================================
        // DEPLOY
        // ====================================================

        stage("Deploy") {

            steps {

                withCredentials([
                    string(
                        credentialsId: 'jwt-key',
                        variable: 'JWT_KEY'
                    ),
                    string(
                        credentialsId: 'google-client-id',
                        variable: 'GOOGLE_CLIENT_ID'
                    ),
                    string(
                        credentialsId: 'google-client-secret',
                        variable: 'GOOGLE_CLIENT_SECRET'
                    ),
                    string(
                        credentialsId: 'smtp-password',
                        variable: 'SMTP_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        cd "${WORKSPACE}"

                        CURRENT_IP=$(cat .current_ip)

                        echo "=============================================="
                        echo "Deploying TikTok Clone"
                        echo "Server IP: ${CURRENT_IP}"
                        echo "Image tag: ${BUILD_NUMBER}"
                        echo "=============================================="

                        export CURRENT_IP
                        export JWT_KEY
                        export GOOGLE_CLIENT_ID
                        export GOOGLE_CLIENT_SECRET
                        export SMTP_PASSWORD
                        export IMAGE_TAG="${BUILD_NUMBER}"

                        echo "Stopping old containers..."

                        docker compose \
                          -f "${COMPOSE_FILE}" \
                          -p tiktok-clone \
                          down \
                          --remove-orphans || true

                        echo "Starting new containers..."

                        docker compose \
                          -f "${COMPOSE_FILE}" \
                          -p tiktok-clone \
                          up \
                          -d

                        echo "=============================================="
                        echo "Deployment completed"
                        echo "=============================================="

                        docker compose \
                          -f "${COMPOSE_FILE}" \
                          -p tiktok-clone \
                          ps
                    '''
                }
            }
        }


        // ====================================================
        // CLEANUP
        // ====================================================

        stage("Cleanup") {

            steps {

                sh '''
                    set +e

                    echo "Cleaning unused Docker images..."

                    docker image prune -f

                    docker logout
                '''
            }
        }
    }


    // ========================================================
    // POST
    // ========================================================

    post {

        success {

            echo "=============================================="
            echo "TikTok Clone CI/CD SUCCESS"
            echo "Build: ${BUILD_NUMBER}"
            echo "=============================================="
        }

        failure {

            echo "=============================================="
            echo "TikTok Clone CI/CD FAILED"
            echo "Build: ${BUILD_NUMBER}"
            echo "=============================================="
        }
    }
}

