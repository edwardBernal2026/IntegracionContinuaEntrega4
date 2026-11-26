#!/usr/bin/env sh
# Prueba de ida y vuelta dentro de la red de Docker, usando solo NOMBRES DE SERVICIO:
#   cliente curl --(http://app:3000)--> app --(db:5432)--> db
# El cliente es un contenedor temporal conectado a la misma red, así que no se usa
# localhost ni ninguna IP fija. Si algún paso falla, el script termina con error
# (y el pipeline de Jenkins o de GitHub Actions queda en rojo).
set -e

RED="${RED:-red_notas}"
API="http://app:3000"
CURL="docker run --rm --network $RED curlimages/curl:8.11.1 -sS"
docker pull -q curlimages/curl:8.11.1 >/dev/null

echo "== 1. El contenedor app resuelve el nombre de servicio 'db' (DNS interno de Docker) =="
docker compose exec -T app getent hosts db

echo
echo "== 2. Estado de la API y de su conexión con db (curl $API/health) =="
$CURL --fail "$API/health"
echo

echo
echo "== 3. Guardar una nota (curl -X POST $API/notas) =="
TEXTO="Prueba de comunicacion $(date '+%Y-%m-%d %H:%M:%S')"
RESP=$($CURL -X POST "$API/notas" -H 'Content-Type: application/json' \
  -d "{\"texto\": \"$TEXTO\"}" -w '\nHTTP %{http_code}')
echo "$RESP"
echo "$RESP" | grep -q 'HTTP 201'
ID=$(echo "$RESP" | head -n 1 | sed -E 's/.*"id":([0-9]+).*/\1/')

echo
echo "== 4. Leer la nota guardada (curl $API/notas/$ID) =="
LEIDA=$($CURL "$API/notas/$ID" -w '\nHTTP %{http_code}')
echo "$LEIDA"
echo "$LEIDA" | grep -q 'HTTP 200'

echo
echo "== 5. Verificar el dato directamente en PostgreSQL (contenedor db) =="
docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM notas ORDER BY id DESC LIMIT 3;"'

echo "$LEIDA" | grep -q "$TEXTO" && echo "RESULTADO: OK - el dato hizo ida y vuelta app -> db -> app usando nombres de servicio"
