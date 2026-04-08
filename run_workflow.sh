#!/bin/bash

# 1. Definir la ruta del proyecto
PROJECT_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# 2. Leer secretos limpiando espacios y saltos de línea
HOSTNAME=$(cat "${PROJECT_FOLDER}/secrets/HOSTNAME" | tr -d '[:space:]')
JENKINS_URL="http://${HOSTNAME}"

USER="mpique"
API_TOKEN=$(cat "${PROJECT_FOLDER}/secrets/JENKINS_API_TOKEN" | tr -d '[:space:]')
JOB="imarina"
BUILD_TOKEN=$(cat "${PROJECT_FOLDER}/secrets/JENKINS_BUILD_TOKEN" | tr -d '[:space:]')
ID_VALUE=$1

echo "--- Iniciando petición a Jenkins ---"

# Paso 1: Obtener el Crumb
echo "Obteniendo Crumb..."
request=$(curl -s -u "${USER}:${API_TOKEN}" "${JENKINS_URL}/crumbIssuer/api/json")


CRUMB=$(echo "$request" | jq -r '.crumb' 2>/dev/null)




# Paso 2: Lanzar el Build
echo "Lanzando el workflow con ID: $ID_VALUE"



# USAMOS --data-urlencode para que curl maneje los caracteres raros (como £, !, >) por nosotros
curl -v -X POST \
     -u "${USER}:${API_TOKEN}" \
     -H "Jenkins-Crumb:$CRUMB" \
     --data-urlencode "ID=${ID_VALUE}" \
     "${JENKINS_URL}/job/${JOB}/buildWithParameters"
