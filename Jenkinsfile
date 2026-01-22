pipeline {
    agent { label 'pav1' }

    environment {
        PYTHONNOUSERSITE          = "1"
        SSH_KEY_PATH              = "/home/ubuntu/.ssh/id_rsa"
        ANSIBLE_HOST_KEY_CHECKING = "False"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Smoke test (local)') {
            steps {
                sh '''
                    set -e
                    echo "==> Local docker-compose build & smoke test"

                    docker-compose down -v || true
                    docker-compose up -d --build

                    echo "==> Waiting for API"
                    sleep 15

                    echo "==> Curl /health"
                    curl -f http://localhost:8000/health
                '''
            }
        }

        stage('Terraform: provision infra') {
            steps {
                dir('openstack') {
                    sh '''
                        set -e
                        echo "==> Source OpenStack creds"
                        . /home/ubuntu/openrc-jenkins.sh

                        echo "==> Ensure keypair Petroshenko does not exist"
                        openstack keypair delete Petroshenko || true

                        echo "==> Generate terraform.tfvars"
                        cat > terraform.tfvars <<EOF
auth_url      = "${OS_AUTH_URL}"
tenant_name   = "${OS_PROJECT_NAME}"
user_name     = "${OS_USERNAME}"
password      = "${OS_PASSWORD}"
region        = "${OS_REGION_NAME:-RegionOne}"

image_name    = "ununtu-22.04"        # здесь должно быть точное имя образа из Horizon
flavor_name   = "m1.medium"
network_name  = "sutdents-net"

public_ssh_key = "$(cat /home/ubuntu/.ssh/id_rsa.pub)"
EOF

                        echo "==> Terraform init"
                        terraform init -input=false

                        echo "==> Terraform apply"
                        terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('Wait for VM SSH') {
            steps {
                script {
                    def elkIp = sh(
                        script: "cd openstack && terraform output -raw Petroshenko-terraform_ip",
                        returnStdout: true
                    ).trim()

                    echo "Waiting for SSH on ${elkIp}"

                    sh """
                        set -e
                        for i in \$(seq 1 30); do
                            echo "==> Checking SSH (${elkIp}) attempt \$i"
                            if nc -z -w 5 ${elkIp} 22; then
                                echo "==> SSH is UP!"
                                exit 0
                            fi
                            echo "==> SSH not ready, sleep 10s"
                            sleep 10
                        done
                        echo "ERROR: SSH did not start in time"
                        exit 1
                    """
                }
            }
        }

        stage('Ansible: deploy to ELK VM') {
            steps {
                script {
                    def elkIp = sh(
                        script: "cd openstack && terraform output -raw Petroshenko-terraform_ip",
                        returnStdout: true
                    ).trim()

                    echo "ELK VM IP from Terraform: ${elkIp}"

                    sh """
                        set -e

                        # На всякий случай удаляем старый host key для этого IP
                        mkdir -p ~/.ssh
                        ssh-keygen -R ${elkIp} || true

                        cd ansible

                        echo "==> Generate inventory.ini"
                        cat > inventory.ini <<EOF
[elk]
${elkIp} ansible_user=ubuntu ansible_ssh_private_key_file=${SSH_KEY_PATH}
EOF

                        echo "==> Run ansible-playbook"
                        ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS: Full build → infra → deploy completed."
        }
        failure {
            echo "Pipeline FAILED."
        }
    }
}
