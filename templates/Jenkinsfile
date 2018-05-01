// Build-Setup-Test (no prior cleanup; leave container running after test)
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh '''
                    echo 'Build image'
                    rm conf.sh 2> /dev/null || true
                    ln -sf conf.sh.default conf.sh
                    if [[ $nocache ]]; then
                        ./dscripts/build.sh  -p -c
                    else
                        ./dscripts/build.sh  -p
                    fi
                '''
            }
        }
        stage('Test: Setup persistent volumes') {
            steps {
                sh '''#!/bin/bash
                    echo "test if already setup"
                    ./dscripts/manage.sh statcode
                    is_running=$?
                    if (( $is_running > 0 )); then
                        ./dscripts/run.sh -I  /scripts/is_initialized.sh
                        is_init=$?
                    else
                        ./dscripts/exec.sh -I  /scripts/is_initialized.sh
                        is_init=$?
                    fi
                    if (( $is_init != 0 )); then
                        echo "setup test config"
                        ./dscripts/run.sh -I  /scripts/init_gitrepos_su.sh
                        if (( $is_running > 0 )); then
                            echo "start server"
                            ./dscripts/run.sh 
                            ./dscripts/manage.sh  logs
                        fi
                    else
                        echo 'skipping  - already setup'
                    fi
                '''
            }
        }
    }
    post {
        always {
          echo 'container status'
          sh './dscripts/manage.sh  status'
        }
    }
}