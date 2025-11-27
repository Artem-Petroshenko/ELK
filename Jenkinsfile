pipeline {
    agent {label 'l1'}

    environment {
        PYTHONNOUSERSITE = "1"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker images') {
            steps {
                sh 'docker-compose build'
            }
        }

        stage('Run Services') {
            steps {
                sh 'docker-compose up -d'
            }
        }

        stage('Smoke Test') {
            steps {
                sh 'sleep 10'
                sh 'curl -f http://localhost:8000/health'
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS: API + ELK up and running!"
        }
        failure {
            echo "Pipeline FAILED"
        }
    }
}
