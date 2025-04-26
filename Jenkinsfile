// Mendefinisikan variabel global yang akan digunakan di seluruh pipeline
def DOCKERHUB_CREDENTIALS_ID = 'dockerhub-credentials' // Sesuaikan dengan ID kredensial Docker Hub di Jenkins
def TARGET_SERVER_SSH_CREDENTIALS_ID = 'web-app-server-ssh-key' // Sesuaikan dengan ID kredensial SSH di Jenkins
def GITHUB_REPO_NAME = 'simple-nginx-app' // Sesuaikan dengan nama repo (digunakan untuk nama image)
def DOCKERHUB_USERNAME = 'avimajid' // Ganti dengan username Docker Hub
def TARGET_SERVER_IP = '34.101.223.209' // Ganti dengan IP atau hostname server target
def TARGET_SERVER_USER = 'userdeploy' // Ganti dengan user SSH di server target
def CONTAINER_NAME = 'my-nginx-app' // Nama kontainer yang akan berjalan di server target
def APP_PORT = 9090 // Port di host target yang akan di-map ke port 80 kontainer

// Variabel Spesifik SonarQube
def SONARQUBE_SERVER_NAME = 'MySonarQubeServer' // Sesuaikan dengan Nama Server SonarQube di Jenkins Config
def SONARQUBE_PROJECT_KEY = "com.yomamen:${GITHUB_REPO_NAME}" // Kunci Unik Project di SonarQube (sesuaikan!)


pipeline {
    agent any // Menjalankan pipeline di agent Jenkins mana saja yang tersedia

    environment {
        // Membuat nama image unik dengan nomor build Jenkins
        IMAGE_NAME = "${DOCKERHUB_USERNAME}/${GITHUB_REPO_NAME}:${env.BUILD_NUMBER}"
        LATEST_IMAGE_NAME = "${DOCKERHUB_USERNAME}/${GITHUB_REPO_NAME}:latest"
        // Path ke Trivy (sesuaikan jika perlu)
        TRIVY_PATH = '/snap/bin/trivy' // Ganti jika path instalasi Trivy berbeda
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo 'Mengambil kode sumber dari GitHub...'
                // Mengambil kode dari SCM (GitHub) yang dikonfigurasi di job Jenkins
                checkout scm
            }
        }
        stage('2. SonarQube Analysis') {
            steps {
                script {
                    // Menggunakan nama Konfigurasi SonarQube Server dari Jenkins System Config
                    // dan nama Konfigurasi SonarScanner dari Jenkins Global Tools Config
                    def scannerHome = tool name: 'SonarScanner Default', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
                    // Menggunakan wrapper untuk inject URL & Token SonarQube
                    withSonarQubeEnv(SONARQUBE_SERVER_NAME) {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=${SONARQUBE_PROJECT_KEY} \
                            -Dsonar.sources=. \
                            -Dsonar.projectName=${GITHUB_REPO_NAME} \
                            -Dsonar.projectVersion=${env.BUILD_NUMBER} \
                            -Dsonar.host.url=${env.SONAR_HOST_URL} \
                            -Dsonar.login=${env.SONAR_AUTH_TOKEN}
                        """
                        // Catatan: -Dsonar.host.url dan -Dsonar.login di-inject oleh withSonarQubeEnv
                        // Jika ada file konfigurasi sonar-project.properties di repo, beberapa -D flag bisa dihilangkan
                    }
                }
            }
        }

        stage('3. Build Docker Image') {
            steps {
                script {
                    echo "Membangun image Docker: ${IMAGE_NAME}"
                    // Menggunakan plugin Docker Pipeline untuk build image
                    docker.build(IMAGE_NAME, '.') // '.' berarti Dockerfile ada di root workspace
                }
            }
        }

        stage('4. Scan Image with Trivy') {
            steps {
                echo "Memindai image ${IMAGE_NAME} dengan Trivy..."
                // Menjalankan Trivy dari shell. Pipeline akan gagal jika ditemukan kerentanan HIGH atau CRITICAL (--exit-code 1)
                // --ignore-unfixed digunakan agar tidak gagal karena vuln yg belum ada patchnya
                // Sesuaikan severity sesuai kebutuhan (misal: 'CRITICAL' saja)
                sh "trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed ${IMAGE_NAME}"
            }
        }


        stage('5. Push Image to Docker Hub') {
            // Stage ini hanya berjalan jika stage sebelumnya (Scan) berhasil
            steps {
                script {
                    echo "Mendorong image ${IMAGE_NAME} ke Docker Hub..."
                    // Menggunakan Docker Hub credentials yang sudah dikonfigurasi
                    docker.withRegistry('https://registry.hub.docker.com', DOCKERHUB_CREDENTIALS_ID) {
                        // Push image dengan tag nomor build
                        docker.image(IMAGE_NAME).push()
                        // Juga push image dengan tag 'latest'
                        docker.image(IMAGE_NAME).push('latest')
                        echo "Image ${IMAGE_NAME} dan ${LATEST_IMAGE_NAME} berhasil didorong."
                    }
                }
            }
        }

        stage('6. Deploy to Target Server') {
            // Stage ini hanya berjalan jika stage sebelumnya (Push) berhasil
            steps {
                echo "Mendeploy image ${LATEST_IMAGE_NAME} ke server target ${TARGET_SERVER_IP}..."
                // Menggunakan SSH Agent plugin dengan kredensial SSH yang dikonfigurasi
                sshagent([TARGET_SERVER_SSH_CREDENTIALS_ID]) {
                    // Menjalankan perintah di server target via SSH
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TARGET_SERVER_USER}@${TARGET_SERVER_IP}
                            echo 'Menarik image terbaru dari Docker Hub...'
                            docker pull ${LATEST_IMAGE_NAME}

                            echo 'Menghentikan dan menghapus kontainer lama (jika ada)...'
                            docker stop ${CONTAINER_NAME} || true
                            docker rm ${CONTAINER_NAME} || true

                            echo 'Menjalankan kontainer baru...'
                            docker run -d --name ${CONTAINER_NAME} -p ${APP_PORT}:80 ${LATEST_IMAGE_NAME}

                            echo 'Deployment selesai. Aplikasi berjalan di http://${TARGET_SERVER_IP}:${APP_PORT}'
                    """
                }
            }
        }
    }

    post {
        // Tindakan yang dilakukan setelah semua stage selesai, terlepas dari statusnya
        always {
            echo 'Pipeline selesai.'
            // Membersihkan workspace Jenkins
            cleanWs()
        }
        success {
            echo 'Pipeline berhasil!'
            // Bisa ditambahkan notifikasi (email, Slack, dll.)
        }
        failure {
            echo 'Pipeline gagal!'
            // Bisa ditambahkan notifikasi kegagalan
        }
        unstable {
            // Biasanya karena test gagal, tapi tidak relevan di pipeline ini
            echo 'Pipeline tidak stabil.'
        }
    }
}
