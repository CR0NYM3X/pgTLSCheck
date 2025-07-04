#!/bin/bash

# Variables por defecto
HOST="127.0.0.1"
PORT=5432
USERNAME="postgres"
DBNAME="postgres"
ASK_PASSWORD=false
NO_PASSWORD=true
VERBOSE=0
OUTFILE="/tmp/sslout.txt"
TLS_VERSIONS=("tls1" "tls1_1" "tls1_2" "tls1_3") # Lista de versiones TLS a testear
TIMEOUT=2
TLS_SCAN_ENABLED=0
DATE_CHECK=0
TLS_CIPHER_AUDIT_ENABLED=0
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
    echo "  --tls-scan                  Escanea versiones TLS soportadas"
    echo "  --tls-cipher-audit          Verificar los tipos de ciphers soportadas"
    echo "  --tls-connect-check         Verifica conexión segura a PostgreSQL"
    echo "  --date-check                validación de fechas del certificado"    
    echo "  -f, --file=ARCHIVO          Ruta donde se guardara la salida impresa en la terminal"
    echo "  --help                      Muestra esta ayuda"
    echo ""
    echo "Ejemplo:"
    echo "  ./pgTLSCheck.sh --host=localhost --port=5432 --username=admin --dbname=postgres --password"
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
            shift
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
        --tls-cipher-audit)
           TLS_CIPHER_AUDIT_ENABLED=1
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

# Validaciones obligatorias
if [[ -z "$HOST" || -z "$PORT" ]]; then
    echo "❌ Error: Debes especificar al menos --host y --port"
    exit 1
fi

if [[ "$ASK_PASSWORD" == true && "$NO_PASSWORD" == true ]]; then
    echo "❌ Error: No puedes usar --password y --no-password al mismo tiempo"
    exit 1
fi

if [[ "$DATE_CHECK" == "1" && "$VERBOSE" == "1"  ]]; then
    echo "❌ Error: No se puede usar el --verbose=1 con --date-check"
    exit 1
fi


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
echo -e "${YELLOW}• Archivo de salida:      ${RESET}${BOLD}$OUTFILE${RESET}"

echo -e "${CYAN}${BOLD}═════════════════════════════════════════════════════════${RESET}\n"


if [[ "$VERBOSE" == "1"   ]]; then
  BRIEF_FLAG="-brief"
fi



########### LÓGICA DEL PROGRAMA ############


# ********************************** INICIO DE FUNCIONES ***********************************************

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

# ********************************** FINAL DE FUNCIONES ***********************************************





if [[ "$TLS_SCAN_ENABLED" == "1" ]]; then
  for VERSION in "${TLS_VERSIONS[@]}"; do
    echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}${BOLD}🔍 Escaneando TLS ${VERSION^^} en $HOST:$PORT${RESET}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${RESET}"

    CMD="echo | timeout $TIMEOUT openssl s_client -connect $HOST:$PORT \
      -starttls postgres -verify_return_error -tlsextdebug -status \
      -showcerts -$VERSION $BRIEF_FLAG 2>&1"

    OUTPUT_TLS_CONNECT=$(eval "$CMD")
    OUTPUT_DETAILS_CERT=$(echo "$OUTPUT_TLS_CONNECT" | openssl x509 -noout -text 2>&1)
    OUTPUT_DATES_CERT=$(echo "$OUTPUT_TLS_CONNECT"  | openssl x509 -noout -dates 2>&1)
    
    NEGOTIATED=$(echo "$OUTPUT_TLS_CONNECT" | grep -v 'Cipher is (NONE)' | grep -E 'Ciphersuite:|Cipher is' | head -1 | awk -F':' '{print $NF}' | awk '{print $NF}' | tr -d '\r')

    if [[ -n "$NEGOTIATED" ]]; then
      if [[ "$VERSION" == "tls1" || "$VERSION" == "tls1_1" ]]; then
        echo -e "\n${MAGENTA}${BOLD}⚠️ Resultado (obsoleto):${RESET}"
        echo -e "   ${GREEN}${BOLD}✔ Conexión exitosa${RESET}"
        echo -e "   ${YELLOW}• Cipher negociado: ${BOLD}$NEGOTIATED${RESET}"
        echo -e "   ${RED}• Riesgo alto: TLS obsoleto (${VERSION})${RESET}"
        if [[ "$VERBOSE" -ne "1" ]]; then 
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "subject:" | sed 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "issuer:" | sed 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "DNS:" | sed 's/^[ \t]*//' )${RESET}"
        fi        
        if [[ "$DATE_CHECK" == "1" ]]; then 
          check_cert_validity "$OUTPUT_DATES_CERT"
        fi
      else
        echo -e "\n${GREEN}${BOLD}✅ Resultado (moderno):${RESET}"
        echo -e "   ${GREEN}${BOLD}✔ Conexión exitosa${RESET}"
        echo -e "   ${GREEN}• Cipher negociado: ${BOLD}$NEGOTIATED${RESET}"
        echo -e "   ${GREEN}• Seguridad avanzada: TLS ${VERSION^^}${RESET}"
        if [[ "$VERBOSE" -ne "1" ]]; then 
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "subject:" | sed 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "issuer:" | sed 's/^[ \t]*//' )${RESET}"
          echo -e "   ${YELLOW}• $(echo "$OUTPUT_DETAILS_CERT" | grep -Ei "DNS:" | sed 's/^[ \t]*//' )${RESET}"
        fi        
        if [[ "$DATE_CHECK" == "1" ]]; then 
          check_cert_validity "$OUTPUT_DATES_CERT"
        fi        
      fi
    else
      echo -e "\n${RED}${BOLD}❌ Resultado:${RESET}"
      echo -e "   ${RED}• No se pudo establecer conexión TLS (${VERSION})${RESET}"
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




