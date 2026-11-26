#!/usr/bin/env sh
# Prueba de ida y vuelta dentro de la red de Docker, usando solo NOMBRES DE SERVICIO:
#   cliente curl --(http://app:3000)--> app --(db:5432)--> db
# El cliente es un contenedor temporal conectado a la misma red, así que no se usa
# localhost ni ninguna IP fija. Si algún paso falla, el script termina con error
# (y el pipeline de Jenkins o de GitHub Actions queda en rojo).
# Si se define JUNIT=<archivo.xml>, también escribe un reporte JUnit (lo publica Jenkins).

RED="${RED:-red_notas}"
API="http://app:3000"
CURL="docker run --rm --network $RED curlimages/curl:8.11.1 -sS"
JUNIT="${JUNIT:-}"
CASOS=""
TOTAL=0
FALLAS=0

registrar() { # nombre, estado (ok|falla), mensaje
  TOTAL=$((TOTAL + 1))
  if [ "$2" = "ok" ]; then
    CASOS="$CASOS<testcase classname=\"comunicacion_app_db\" name=\"$1\"/>"
  else
    FALLAS=$((FALLAS + 1))
    CASOS="$CASOS<testcase classname=\"comunicacion_app_db\" name=\"$1\"><failure message=\"$3\"/></testcase>"
  fi
}

terminar() {
  if [ -n "$JUNIT" ]; then
    mkdir -p "$(dirname "$JUNIT")"
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="Prueba de comunicacion app-db" tests="%s" failures="%s">%s</testsuite>\n' \
      "$TOTAL" "$FALLAS" "$CASOS" > "$JUNIT"
  fi
  echo
  if [ "$FALLAS" -eq 0 ]; then
    echo "RESULTADO: OK - el dato hizo ida y vuelta app -> db -> app usando nombres de servicio ($TOTAL pasos)"
    exit 0
  fi
  echo "RESULTADO: FALLO - la ida y vuelta app -> db -> app no se completó"
  exit 1
}

paso_ok() { registrar "$1" ok; }
paso_falla() { registrar "$1" falla "$2"; echo "FALLO: $2"; terminar; }

docker pull -q curlimages/curl:8.11.1 >/dev/null

echo "== 1. El contenedor app resuelve el nombre de servicio 'db' (DNS interno de Docker) =="
if docker compose exec -T app getent hosts db; then paso_ok "1_app_resuelve_db"
else paso_falla "1_app_resuelve_db" "app no resuelve el nombre db"; fi

echo
echo "== 2. Prueba de humo: estado de la API y de su conexión con db (curl $API/health) =="
if $CURL --fail "$API/health"; then echo; paso_ok "2_prueba_de_humo_health"
else paso_falla "2_prueba_de_humo_health" "GET /health no respondio 200"; fi

echo
echo "== 3. Guardar una nota (curl -X POST $API/notas) =="
TEXTO="Prueba de comunicacion $(date '+%Y-%m-%d %H:%M:%S')"
RESP=$($CURL -X POST "$API/notas" -H 'Content-Type: application/json' \
  -d "{\"texto\": \"$TEXTO\"}" -w '\nHTTP %{http_code}')
echo "$RESP"
if echo "$RESP" | grep -q 'HTTP 201'; then paso_ok "3_guardar_nota_post_201"
else paso_falla "3_guardar_nota_post_201" "POST /notas no respondio 201 Created"; fi
ID=$(echo "$RESP" | head -n 1 | sed -E 's/.*"id":([0-9]+).*/\1/')

echo
echo "== 4. Leer la nota guardada (curl $API/notas/$ID) =="
LEIDA=$($CURL "$API/notas/$ID" -w '\nHTTP %{http_code}')
echo "$LEIDA"
if echo "$LEIDA" | grep -q 'HTTP 200' && echo "$LEIDA" | grep -q "$TEXTO"; then paso_ok "4_leer_nota_get_200"
else paso_falla "4_leer_nota_get_200" "GET /notas/id no devolvio la nota guardada"; fi

echo
echo "== 5. Verificar el dato directamente en PostgreSQL (contenedor db) =="
TABLA=$(docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM notas ORDER BY id DESC LIMIT 3;"')
echo "$TABLA"
if echo "$TABLA" | grep -q "$TEXTO"; then paso_ok "5_dato_en_postgresql"
else paso_falla "5_dato_en_postgresql" "la nota no esta en la tabla notas"; fi

terminar
