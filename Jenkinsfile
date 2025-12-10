pipeline {
    agent { label 'l1' }     // твой агент-ВМ RomanS

    environment {
        PYTHONNOUSERSITE = "1"
        SSH_KEY_PATH     = "/home/ubuntu/id_rsa_elk_tf"   // приватный ключ для доступа на ELK-ВМ
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Smoke test (local docker-compose)') {
            steps {
                sh '''
                    set -e
                    echo "==> Local docker-compose build & smoke test"

                    docker-compose down -v || true
                    docker-compose up -d --build

                    echo "==> Waiting for API to start..."
                    sleep 15

                    echo "==> Smoke test /health"
                    curl -f http://localhost:8000/health
                '''
            }
        }

        stage('Terraform: provision infra') {
            steps {
                dir('openstack') {
                    // ВАЖНО: одинарные кавычки, чтобы $OS_* разворачивал bash, а не Groovy
                    sh '''
                        set -e
                        echo "==> Source OpenStack creds for Jenkins"
                        source ~/openrc-jenkins.sh

                        echo "==> Generate terraform.tfvars"
                        cat > terraform.tfvars <<EOF
auth_url      = "${OS_AUTH_URL}"
tenant_name   = "${OS_PROJECT_NAME}"
user_name     = "${OS_USERNAME}"
password      = "${OS_PASSWORD}"
region        = "${OS_REGION_NAME:-RegionOne}"

# значения ниже подставь такие же, как в локальном terraform.tfvars
image_name    = "ununtu-22.04"      # ИМЯ ОБРАЗА ИЗ HORIZON
flavor_name   = "m1.medium"          # твой flavor
network_name  = "sutdents-net"      # твоя сеть

public_ssh_key = "$(cat ~/id_rsa_elk_tf.pub)"
EOF

                        echo "==> Terraform init"
                        terraform init -input=false

                        echo "==> Terraform apply"
                        terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('Ansible: deploy to ELK VM') {
            steps {
                script {
                    // Берём IP из Terraform output
                    def elkIp = sh(
                        script: "cd openstack && terraform output -raw elk_vm_ip",
                        returnStdout: true
                    ).trim()

                    echo "ELK VM IP from Terraform: ${elkIp}"

                    // Генерируем inventory.ini и запускаем Ansible
                    sh """
                        set -e
                        cd ansible

                        echo "==> Generate inventory.ini"
                        cat > inventory.ini <<EOF
[elk]
${elkIp} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_KEY_PATH}
EOF

                        echo "==> Run ansible-playbook"
                        ansible-playbook -i inventory.ini playbook.yml
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS: build + infra + deploy completed."
        }
        failure {
            echo "Pipeline FAILED."
        }
    }
}
