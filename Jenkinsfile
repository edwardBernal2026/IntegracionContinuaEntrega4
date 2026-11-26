// =============================================================
// Entrega proyecto 2 — Pipeline declarativo en Jenkins para los
// dos contenedores de la Entrega 1 (app: API de notas, db: PostgreSQL)
// Etapas: revisar API en contenedor efímero -> preparar entorno con credencial
//         -> construir las 2 imágenes -> levantar -> prueba de comunicación
// =============================================================
pipeline {
  agent any
  options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 20, unit: 'MINUTES')
    disableConcurrentBuilds()
  }
  // Integración con GitHub: Jenkins revisa el repositorio cada ~2 minutos y
  // dispara un build cuando encuentra un commit nuevo en main (Poll SCM)
  triggers {
    pollSCM('H/2 * * * *')
  }
  environment {
    TAG = "${env.BUILD_NUMBER}"                          // imágenes entrega3-app:N y entrega3-db:N
    COMPOSE_PROJECT_NAME = "notas-ci-${env.BUILD_NUMBER}" // proyecto de Compose aislado por build
    PREFIJO = "notas-ci${env.BUILD_NUMBER}"               // nombres de contenedores y volumen
    RED = "red_notas_ci${env.BUILD_NUMBER}"               // red propia del build
    APP_HOST_PORT = '127.0.0.1:'                          // puerto del host aleatorio (no choca con el 3000)
    DB_PASS = credentials('notas-db-password')            // credencial "Secret text" guardada en Jenkins
  }
  stages {
    stage('Revisar API') {
      // Contenedor efímero solo para esta etapa: instala dependencias y revisa la sintaxis
      agent {
        docker {
          image 'node:20.18.1-alpine3.20'
          args '-e npm_config_cache=/tmp/.npm'
          reuseNode true
        }
      }
      steps {
        dir('app') {
          sh '''
            node --version
            npm ci --no-audit --no-fund
            node --check src/index.js
            node -e "require('express'); require('pg'); console.log('Dependencias express y pg cargadas')"
          '''
        }
      }
    }
    stage('Preparar entorno') {
      steps {
        // El .env se arma con la contraseña de la credencial (Jenkins la oculta en el log)
        sh '''
          sed "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASS/" .env.example > .env
          docker compose config --quiet
          echo "docker-compose.yml válido; proyecto $COMPOSE_PROJECT_NAME"
        '''
      }
    }
    stage('Construir imágenes') {
      steps {
        sh '''
          docker compose build
          docker image ls --format "{{.Repository}}:{{.Tag}}  {{.Size}}" | grep -E "^entrega3-(app|db):$TAG "
        '''
      }
    }
    stage('Levantar contenedores') {
      steps {
        sh '''
          docker compose up -d --wait --wait-timeout 90
          docker compose ps
        '''
      }
    }
    stage('Prueba de comunicación') {
      steps {
        // Ida y vuelta app -> db -> app con curl; el reporte queda como artefacto del build
        sh '''
          mkdir -p reportes
          sh scripts/prueba-comunicacion.sh > reportes/prueba-comunicacion.txt 2>&1 && rc=0 || rc=$?
          cat reportes/prueba-comunicacion.txt
          exit $rc
        '''
      }
      post {
        always { archiveArtifacts artifacts: 'reportes/*.txt', allowEmptyArchive: true }
      }
    }
  }
  post {
    always {
      sh '''
        docker compose logs --no-color --tail 30 || true
        docker compose down -v --remove-orphans || true
        rm -f .env
      '''
    }
    success { echo "Build ${env.BUILD_NUMBER} OK: imágenes entrega3-app:${env.TAG} y entrega3-db:${env.TAG} probadas" }
    failure { echo 'El pipeline falló: revisa la etapa en rojo' }
  }
}
