pipeline {
  agent any
  stages {
    stage('Pester') {
      parallel {
        stage('Pester') {
          steps {
            sh 'echo "hello"'
          }
        }
        stage('PSScriptAnalyzer') {
          steps {
            sh 'echo "hello"'
          }
        }
      }
    }
    stage('Create Manifest') {
      steps {
        sh 'echo "hello"'
      }
    }
    stage('Publish to Nexus') {
      steps {
        sh 'echo "hello"'
      }
    }
  }
}