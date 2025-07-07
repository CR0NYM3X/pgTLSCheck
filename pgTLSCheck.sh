#!/bin/bash
# Nuevas actualizaciones , se agregara el guardado y en diferentes formatos y te permitira dar recomendaciones de que configuraciones colocar en postgresql.conf

# Variables por defecto
HOST='127.0.0.1'
PORT=5432
USERNAME='postgres'
DBNAME='postgres'
PGPASSWORD='NADA'
ASK_PASSWORD=false
NO_PASSWORD=true
VERBOSE=0
OUTFILE="/tmp/sslout.txt"
TLS_VERSIONS=("tls1" "tls1_1" "tls1_2" "tls1_3") # Lista de versiones TLS a testear
TIMEOUT=2
TLS_SCAN_ENABLED=0
DATE_CHECK=0
TLS_SUPPORTED_CIPHER_ENABLED=0
TLS_CONNECT_CHECK_ENABLED=0
BRIEF_FLAG="-brief"
BINOPENSSL="/usr/bin"
BINPSQL="/usr/pgsql-16/bin"
BRIEF_FLAG=""
# 🎨 Colores ANSI
RED='\e[31m'         # Errores y alertas
GREEN='\e[32m'       # Éxito y seguridad
YELLOW='\e[33m'      # Información general
BLUE='\e[34m'        # TLS moderno
MAGENTA='\e[35m'     # Protocolos obsoletos
CYAN='\e[36m'        # Encabezados visuales
BOLD='\e[1m'         # Negritas
RESET='\e[0m'        # Reset estilo
# Binarios
PSQL_BIN='/usr/pgsql-16/bin/psql'
OPENSSL_BIN='/usr/bin/openssl'
AWK_BIN='/usr/bin/awk'
SED_BIN='/usr/bin/sed'
SORT_BIN='/usr/bin/sort'

show_help() {
    echo "pgTLSCheck.sh - Herramienta de escaneo TLS para PostgreSQL"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --host=HOSTNAME         Host o IP del servidor PostgreSQL (por defecto: 127.0.0.1)"
    echo "  -p, --port=PORT             Puerto del servidor PostgreSQL (por defecto: 5432)"
    echo "  -U, --username=USERNAME     Usuario para autenticación (por defecto: postgres)"
    echo "  -d, --dbname=DBNAME         Nombre de la base de datos a la que conectar (por defecto: postgres)"
#    echo "  -w, --no-password           No solicitar contraseña (usa .pgpass o conexión con trust - por defecto:true )"
    echo "  -W, --password              Solicitar contraseña (modo interactivo - por defecto:false)"
    echo "  -v, --verbose=VALOR         Nivel de salida:"
    echo "                                 0 = por defecto solo imprime si cumple o no"
    echo "                                 1 = breve (solo resumen)"
    echo "                                 2 = detallado (Imprime detalles de conexión TLS )"
    echo "                                 3 = detallado (Imprime detalles completos del certificado)"
    echo "                                 4 = detallado (Imprime detalles de conexión TLS  y detalles completos del certificado)"
    echo "  --tls-scan                  Realiza un escaneo de versiones TLS soportadas por el servidor"
    echo "  --tls-supported-ciphers     Enumera y valida los cipher suites aceptados por el servidor"
    echo "                                  (requiere --tls-scan)"
    echo "  --date-check                Verifica la validez y vigencia de los certificados TLS"
    echo "                                 (requiere --tls-scan)"
    echo "  --tls-connect-check         Verifica conexión TLS a PostgreSQL utilizando psql"
#    echo "  -f, --file=ARCHIVO          Ruta donde se guardara la salida impresa en la terminal"
#    echo "  --text                      Imprimir salida en fromato text"
#    echo "  --json                      Imprimir salida en fromato json"
#    echo "  --csv                       Imprimir salida en fromato csv"
    echo "  --help                      Muestra esta ayuda"
    echo ""
    echo "Ejemplo:"
    echo "  ./pgTLSCheck.sh -h 127.0.0.1 -p 5416 -U postgres -v 0 --tls-connect-check --tls-scan --date-check --tls-supported-ciphers"
}

ejecutar() {
  "$@"
}

# Mostrar ayuda si no hay argumentos
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Parseo de argumentos
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--host)
            if [[ -n "$2" && "$2" != -* ]]; then
                HOST="$2"
                shift 2
            else
                echo "❌ Error: Falta valor para el parámetro --host"
                exit 1
            fi
            ;;
        --host=*)
            HOST="${1#*=}"
            shift
            ;;
        -p|--port)
            if [[ -n "$2" && "$2" != -* ]]; then
                PORT="$2"
                shift 2
            else
                echo "❌ Error: Falta valor para el parámetro --port"
                exit 1
            fi
            ;;
        --port=*)
            PORT="${1#*=}"
            shift
            ;;
        -U|--username)
            if [[ -n "$2" && "$2" != -* ]]; then
                USERNAME="$2"
                shift 2
            else
                echo "❌ Error: Falta valor para el parámetro --username"
                exit 1
            fi
            ;;
        --username=*)
            USERNAME="${1#*=}"
            shift
            ;;
        -d|--dbname)
            if [[ -n "$2" && "$2" != -* ]]; then
                DBNAME="$2"
                shift 2
            else
                echo "❌ Error: Falta valor para el parámetro --dbname"
                exit 1
            fi
            ;;
        --dbname=*)
            DBNAME="${1#*=}"
            shift
            ;;
        -w|--no-password)
            NO_PASSWORD=true
            shift
            ;;
        -W|--password)
            ASK_PASSWORD=true
            # Solicita la contraseña sin mostrarla en pantalla
            read -s -p "Introduce tu contraseña: " PGPASSWORD
            shift
            ;;
        -t|--timeout)            
            if [[ -n "$2" && "$2" != -* ]]; then
                TIMEOUT="$2"
                shift 2
            else
                echo "❌ Error: Falta valor para el parámetro --timeout"
                exit 1
            fi
            ;;         
        -v|--verbose)
            if [[ "$2" =~ ^[0-4]$ ]]; then
                VERBOSE="$2"
                shift 2
            else
                echo "❌ Valor inválido para --verbose. Debe ser 0, 1,2 o 4"
                exit 1
            fi
            ;;
        --verbose=*)
            VAL="${1#*=}"
            if [[ "$VAL" =~ ^[0-4]$ ]]; then
                VERBOSE="$VAL"
                shift
            else
                echo "❌ Valor inválido para --verbose. Debe ser 0, 1,2 o 4"
                exit 1
            fi
            ;;

        -f|--file)
            if [[ -n "$2" && "$2" != -* ]]; then
                OUTFILE="$2"
                shift 2
            else
                echo "❌ Error: Falta valor para -f (archivo)"
                exit 1
            fi
            ;;
        --file=*)
            OUTFILE="${1#*=}"
            shift
            ;;

        --tls-scan)
            TLS_SCAN_ENABLED=1
            shift
            ;;
        --tls-supported-ciphers)
           TLS_SUPPORTED_CIPHER_ENABLED=1
           shift
           ;;
        --tls-connect-check)
          TLS_CONNECT_CHECK_ENABLED=1
           shift
           ;;
        --date-check)
          DATE_CHECK=1
           shift
           ;;           
        --csv)
          CSV=1
           shift
           ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "⚠️ Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# ********************************** INICIO -  Validaciones obligatorias **********************************  
if [[ -z "$HOST" || -z "$PORT" ]]; then
    echo "❌ Error: Debes especificar al menos --host y --port"
    exit 1
fi

#if [[ "$ASK_PASSWORD" == true && "$NO_PASSWORD" == true ]]; then
#    echo "❌ Error: No puedes usar --password y --no-password al mismo tiempo"
#    exit 1
#fi

if [[ "$DATE_CHECK" == "1" && "$VERBOSE" == "1"  ]]; then
    echo "❌ Error: No se puede usar el --verbose=1 con --date-check"
    exit 1
fi

# Opcional: validar que no esté vacía
if [[ -z "${PGPASSWORD// }" && "$ASK_PASSWORD" = "true"  ]]; then
  echo "⚠️ La contraseña no puede estar vacía."
  exit 1
fi


if [[ "$DATE_CHECK" == "1" && "$TLS_SCAN_ENABLED" != "1" ]]; then
  echo "❌ Error: la opción --date-check requiere que --tls-scan esté activado." >&2
  exit 1
fi

if [[ "$TLS_SUPPORTED_CIPHER_ENABLED" == "1" && "$TLS_SCAN_ENABLED" != "1" ]]; then
  echo "❌ Error: la opción --tls-supported-ciphers requiere que --tls-scan esté activado." >&2
  exit 1
fi


#********************************** FINAL -  Validaciones obligatorias **********************************  



# Test: mostrar argumentos recibidos
echo -e "\n${CYAN}${BOLD}═════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}${BOLD}📋 Parámetros recibidos:${RESET}"
echo -e "${CYAN}${BOLD}═════════════════════════════════════════════════════════${RESET}"

echo -e "${YELLOW}• Nivel de verbose:       ${RESET}${BOLD}$VERBOSE${RESET}"
echo -e "${YELLOW}• HOST objetivo:          ${RESET}${BOLD}$HOST${RESET}"
echo -e "${YELLOW}• Puerto:                 ${RESET}${BOLD}$PORT${RESET}"
echo -e "${YELLOW}• Usuario (DB):           ${RESET}${BOLD}$USERNAME${RESET}"
echo -e "${YELLOW}• Base de datos:          ${RESET}${BOLD}$DBNAME${RESET}"
echo -e "${YELLOW}• Contraseña requerida:   ${RESET}${BOLD}$ASK_PASSWORD${RESET}"
# echo -e "${YELLOW}• Sin contraseña:         ${RESET}${BOLD}$NO_PASSWORD${RESET}"
#echo -e "${YELLOW}• Archivo de salida:      ${RESET}${BOLD}$OUTFILE${RESET}"
##### VALIDANDO ALCANCE CON EL SERVIOD ANTES DE HACER EL TEST #####
if timeout $TIMEOUT bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
    echo -e "${YELLOW}• Alcance al servidor:${RESET}${GREEN}${BOLD}    EXITOSO${RESET}"
else
    echo -e "${YELLOW}• Alcance al servidor:${RESET}${RED}${BOLD}    FALLIDO${RESET} - [TIMEOUT=$TIMEOUT]"
    exit 1
fi



if [[ "$TLS_CONNECT_CHECK_ENABLED" == "1"  ]]; then

echo -e "${YELLOW}• Verificando conexión a PostgreSQL...${RESET}"

# Ejecutar consulta timeout $TIMEOUT
RESULT=$( PGPASSWORD="$PGPASSWORD" \
  timeout $TIMEOUT $PSQL_BIN -q -X -U "$USERNAME" -h "$HOST" -p "$PORT" -d "$DBNAME" \
  -P format=aligned -P border=2 \
  -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();" 2>&1)

# Verificar si falló la conexión
if [[ $? -ne 0 ]]; then
  echo -e "${RED}   ❌ Error de conexión:${RESET} ${BOLD}$RESULT${RESET}"
  exit 1
fi

# Evaluar si la conexión es segura
if echo "$RESULT" | grep -q "| t "; then
  echo -e "${GREEN}   🔐 Conexión SSL exitosa.${RESET}"
  echo -e "${CYAN}    • Detalles SSL:${RESET}"
  echo "$RESULT"
elif echo "$RESULT" | grep -q "| f "; then
  echo -e "${RED}   ⚠️ Conexión sin SSL.${RESET}"
  echo -e "${CYAN}   • Detalles de la conexión:${RESET}"
  echo "$RESULT"
else
  echo -e "${YELLOW}❓ No se pudo interpretar la salida.${RESET}"
  echo "$RESULT"
fi
echo -e "${CYAN}${BOLD}═════════════════════════════════════════════════════════${RESET}\n"
else
echo -e "${CYAN}${BOLD}═════════════════════════════════════════════════════════${RESET}\n"
fi

if [[ "$VERBOSE" == "1"   ]]; then
  BRIEF_FLAG="-brief"
fi




# ********************************** INICIO - FUNCIONES ***********************************************

## Funcion que valida la fechas de un certificado 
check_cert_validity() {
  local cert_output="$1"

  local not_before_raw not_after_raw not_before_ts not_after_ts now_ts
  not_before_raw=$(echo "$cert_output" | grep 'notBefore=' | cut -d= -f2)
  not_after_raw=$(echo "$cert_output" | grep 'notAfter=' | cut -d= -f2)

  not_before_ts=$(date -d "$not_before_raw" +"%s")
  not_after_ts=$(date -d "$not_after_raw" +"%s")
  now_ts=$(date +"%s")

  local not_before_fmt not_after_fmt
  not_before_fmt=$(date -d "$not_before_raw" +"%d/%m/%Y %H:%M:%S")
  not_after_fmt=$(date -d "$not_after_raw" +"%d/%m/%Y %H:%M:%S")

  local status
  if (( now_ts < not_before_ts )); then
    status="❌ No válido aún"
  elif (( now_ts > not_after_ts )); then
    status="❌ Expirado"
  elif (( (not_after_ts - now_ts) < 604800 )); then
    status="⚠️ Por expirar"
  else
    status="✅ Vigente"
  fi

  echo -e "${CYAN}${BOLD}📄 Estado del Certificado:${RESET}"
  echo -e "   ${YELLOW}• Status:         ${RESET}${BOLD}$status${RESET}"
  echo -e "   ${YELLOW}• Vigencia desde: ${RESET}${BOLD}$not_before_fmt${RESET}"
  echo -e "   ${YELLOW}• Vigencia hasta: ${RESET}${BOLD}$not_after_fmt${RESET}\n"

}



 
# Funcion que valida los cipher soportados
probar_ciphers_tls() {
  local tls_input="$1"
  local tls_label="${tls_input//_/.}"  # ej: tls1_2 → tls1.2

  case "$tls_label" in
    tls1)   TLS_FLAG="tls1" ;;
    tls1.1) TLS_FLAG="tls1_1" ;;
    tls1.2) TLS_FLAG="tls1_2" ;;
    tls1.3) TLS_FLAG="tls1_3" ;;
    *)
      echo -e "${YELLOW}⚠ Versión TLS inválida: $tls_input${RESET}"
      return
      ;;
  esac

  echo -e "\n${BOLD}${MAGENTA}🔍 CIPHERS SOPORTADOS: $tls_label${RESET}"
  printf "%-42s | %-12s\n" "Cipher" "Resultado"
  printf "%-42s-+-%-12s\n" "$(printf '%.0s-' {1..42})" "$(printf '%.0s-' {1..12})"

  local all_ciphers=$($OPENSSL_BIN ciphers  -v  'ALL:eNULL'  | $AWK_BIN '{print $6 " " $2 " " $1}'  | $SED_BIN -e 's/Mac=//g' | $SORT_BIN | $AWK_BIN '{print $2 " " $3}' | $SORT_BIN | $AWK_BIN '{print $2}')
  local supported=0
  local failed=0

  for CIPHER in $all_ciphers; do
    if [[ "$TLS_FLAG" == "tls1_3" ]]; then
      CMD="echo | $OPENSSL_BIN s_client -connect $HOST:$PORT -starttls postgres -$TLS_FLAG -ciphersuites $CIPHER -verify_return_error -brief"
    else
      CMD="echo | $OPENSSL_BIN s_client -connect $HOST:$PORT -starttls postgres -$TLS_FLAG -cipher $CIPHER -verify_return_error -brief"
    fi

    RESULT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1)

    if echo "$RESULT" | grep -q "Cipher"; then
      printf "%-42s | ${GREEN}%-12s${RESET}\n" "$CIPHER" "✔ Conectado"
      ((supported++))
    else
      ((failed++))
    fi
  done

  echo -e "\n${BOLD}📊 Resumen de Ciphers $tls_label:${RESET}"
  echo -e "${GREEN}✔ Ciphers aceptados:${RESET} $supported"
  echo -e "${RED}✘ Ciphers rechazados:${RESET} $failed"

  if [[ $supported -eq 0 ]]; then
    echo -e "\n${YELLOW}⚠ No se logró negociar ningún cipher con TLS $tls_label.${RESET}"
  fi
}



# ********************************** FINAL - FUNCIONES ***********************************************





# ********************************** INICIO - LOGICA DEL SCRIPT ***********************************************

if [[ "$TLS_SCAN_ENABLED" == "1" ]]; then
  for VERSION in "${TLS_VERSIONS[@]}"; do
    echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}${BOLD}🔍 Escaneando TLS ${VERSION^^} en $HOST:$PORT${RESET}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${RESET}"

    CMD="echo | timeout $TIMEOUT $OPENSSL_BIN s_client -connect $HOST:$PORT \
      -starttls postgres -verify_return_error -tlsextdebug -status \
      -showcerts -$VERSION $BRIEF_FLAG 2>&1"

    OUTPUT_TLS_CONNECT=$(eval "$CMD")
    OUTPUT_DETAILS_CERT=$(echo "$OUTPUT_TLS_CONNECT" | $OPENSSL_BIN x509 -noout -text 2>&1)
    OUTPUT_DATES_CERT=$(echo "$OUTPUT_TLS_CONNECT"  | $OPENSSL_BIN x509 -noout -dates 2>&1)
    
    NEGOTIATED=$(echo "$OUTPUT_TLS_CONNECT" | grep -v 'Cipher is (NONE)' | grep -E 'Ciphersuite:|Cipher is' | head -1 | $AWK_BIN -F':' '{print $NF}' | $AWK_BIN '{print $NF}' | tr -d '\r')

    if [[ -n "$NEGOTIATED" ]]; then
      if [[ "$VERSION" == "tls1" || "$VERSION" == "tls1_1" ]]; then
        echo -e "\n${MAGENTA}${BOLD}⚠️ Resultado (obsoleto):${RESET}"
        echo -e "   ${GREEN}${BOLD}✔ Conexión exitosa${RESET}"
        echo -e "   ${YELLOW}• Cipher negociado: ${BOLD}$NEGOTIATED${RESET}"
        echo -e "   ${RED}• Riesgo alto: TLS obsoleto (${VERSION})${RESET}"
        if [[ "$VERBOSE" -ne "1" ]]; then 
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "subject:" | $SED_BIN 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "issuer:" | $SED_BIN 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "DNS:" | $SED_BIN 's/^[ \t]*//' )${RESET}"
        fi        
        if [[ "$DATE_CHECK" == "1" ]]; then 
          check_cert_validity "$OUTPUT_DATES_CERT"
        fi
        if [[ "$TLS_SUPPORTED_CIPHER_ENABLED" == "1" ]]; then 
          probar_ciphers_tls $VERSION
        fi
        
        
      else
        echo -e "\n${GREEN}${BOLD}✅ Resultado (moderno):${RESET}"
        echo -e "   ${GREEN}${BOLD}✔ Conexión exitosa${RESET}"
        echo -e "   ${GREEN}• Cipher negociado: ${BOLD}$NEGOTIATED${RESET}"
        echo -e "   ${GREEN}• Seguridad avanzada: TLS ${VERSION^^}${RESET}"
        if [[ "$VERBOSE" -ne "1" ]]; then 
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "subject:" | $SED_BIN 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "issuer:" | $SED_BIN 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "DNS:" | $SED_BIN 's/^[ \t]*//' )${RESET}"
        fi        
        if [[ "$DATE_CHECK" == "1" ]]; then 
          check_cert_validity "$OUTPUT_DATES_CERT"
        fi
        if [[ "$TLS_SUPPORTED_CIPHER_ENABLED" == "1" ]]; then 
          probar_ciphers_tls $VERSION
        fi
      fi
    else
      echo -e "\n${RED}${BOLD}❌ Resultado:${RESET}"
      echo -e "   ${RED}• No se pudo establecer conexión TLS (${VERSION})${RESET}"
      if [[ "$TLS_SUPPORTED_CIPHER_ENABLED" == "1" ]]; then 
        probar_ciphers_tls $VERSION
      fi
    fi

    if [[ "$VERBOSE" == "1" || "$VERBOSE" == "2" ]]; then
      echo -e "\n${YELLOW}${BOLD}🧪 Detalles de la conexin TLS:${RESET}\n"
      echo "$OUTPUT_TLS_CONNECT"
    elif [[ "$VERBOSE" == "3" ]]; then
      echo -e "\n${YELLOW}${BOLD}🧪 Detalles del certificado TLS:${RESET}\n"
      echo "$OUTPUT_DETAILS_CERT"
    elif [[ "$VERBOSE" == "4" ]]; then
      echo -e "\n${YELLOW}${BOLD}🧪 Detalles de la conexión TLS:${RESET}\n"
      echo "$OUTPUT_TLS_CONNECT"        
      echo -e "\n${YELLOW}${BOLD}🧪 Detalles del certificado TLS:${RESET}\n"
      echo "$OUTPUT_DETAILS_CERT" 
    fi

    
  done
fi

echo ""

# ********************************** FINAL - LOGICA DEL SCRIPT ***********************************************


