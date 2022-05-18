#!/usr/bin/env groovy
/* groovylint-disable CompileStatic, NoDef, VariableTypeRequired */

node {
  stage('src') {
    checkout scm
  }
}

script {
  // TODO: [05/14/2022 schelcj] - include the cpan-audit step
  build_cpan()
}
