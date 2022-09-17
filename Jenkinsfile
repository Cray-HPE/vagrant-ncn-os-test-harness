pipeline {
  agent any
  environment {
    ARTIFACTORY_USER = credentials('ARTIFACTORY_USER')
    ARTIFACTORY_TOKEN = credentials('ARTIFACTORY_TOKEN')
    VAGRANT_NCN_USER = credentials('VAGRANT_NCN_USER')
    VAGRANT_NCN_PASS = credentials('VAGRANT_NCN_PASSWORD')
  }
  stages {
    stage('Create Virtualbox Libvirt Host') {
      steps {
        sh './start.sh'
      }
    }
    stage('Create K8s NCN Vagrant box from latest CSM beta.') {
      steps {
        sh './update_box.sh'
      }
    }
    stage('Launch K8s VM in Libvirt Host') {
      steps {
        sh 'cd k8s_ncn && ./start.sh'
      }
    }
  }
}
