pipeline {
  agent any
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
