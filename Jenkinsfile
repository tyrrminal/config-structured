#!/usr/bin/env groovy
/* groovylint-disable CompileStatic, NoDef, VariableTypeRequired */

node {
  stage('src') {
    checkout scm
  }
}

script {
  withCredentials((credentialsId: '693bcd18-c21e-4e5c-b267-6ebd77183195', variable: 'CONCERT_BB_API_TOKEN')) {
    cpan_audit()
    build_cpan()
    build_docs_cpan()
  }
}
