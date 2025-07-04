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
TLS_CIPHER_AUDIT_ENABLED=0
TLS_CONNECT_CHECK_ENABLED=0
BRIEF_FLAG="-brief"
BINOPENSSL="/usr/bin"
BINPSQL="/usr/pgsql-16/bin"
BRIEF_FLAG="-brief"

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
    echo "                                 0 = por defecto solo imprime true o false"
    echo "                                 1 = breve (solo resumen)"
    echo "                                 2 = detallado (verbose completo de openssl"
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
            if [[ "$2" =~ ^[0-2]$ ]]; then
                VERBOSE="$2"
                shift 2
            else
                echo "❌ Valor inválido para --verbose. Debe ser 0, 1 o 2"
                exit 1
            fi
            ;;
        --verbose=*)
            VAL="${1#*=}"
            if [[ "$VAL" =~ ^[1-2]$ ]]; then
                VERBOSE="$VAL"
                shift
            else
                echo "❌ Valor inválido para --verbose. Debe ser 0, 1 o 2"
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

# Test: mostrar argumentos recibidos
echo "*****************************************************"
echo "📋 Parámetros recibidos:"
echo "Nivel de verbose $VERBOSE"
echo "HOST:     $HOST"
echo "PORT:     $PORT"
echo "USERNAME: $USERNAME"
echo "DBNAME:   $DBNAME"
echo "Contraseña requerida: $ASK_PASSWORD"
#echo "Sin contraseña:       $NO_PASSWORD"
echo "Archivo de salida $OUTFILE"
echo "*****************************************************"

if [[ "$VERBOSE" == "2" ]]; then
  BRIEF_FLAG=""
fi


########### LÓGICA DEL PROGRAMA ############

if [[ "$TLS_SCAN_ENABLED" == "1" ]]; then
  for VERSION in "${TLS_VERSIONS[@]}"; do
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 Escaneando versión TLS: ${VERSION^^} en $HOST:$PORT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    CMD="echo | timeout $TIMEOUT openssl s_client -connect $HOST:$PORT \
      -starttls postgres -verify_return_error -tlsextdebug -status \
      -showcerts -$VERSION $BRIEF_FLAG 2>&1"

    OUTPUT=$(eval "$CMD")
    NEGOTIATED=$(echo "$OUTPUT" | grep "^Cipher" | awk '{print $2}')

    if [[ "$VERBOSE" == "1" ]]; then
      echo -e "\n🧪 Detalles completos del escaneo:\n"
      echo "$OUTPUT"
    fi

    if [[ -n "$NEGOTIATED" ]]; then
      if [[ "$VERSION" == "tls1" || "$VERSION" == "tls1_1" ]]; then
        echo -e "\n⚠  Resultado:"
        echo "   ├─ Estado de conexión: Exitosa"
        echo "   ├─ Cipher negociado: $NEGOTIATED"
        echo "   └─ Alerta de seguridad: 🔥 Versión TLS obsoleta ($VERSION)"
      else
        echo -e "\n✅ Resultado:"
        echo "   ├─ Estado de conexión: Exitosa"
        echo "   ├─ Cipher negociado: $NEGOTIATED"
        echo "   └─ Seguridad: ✔️ Versión TLS moderna ($VERSION)"
      fi
    else
      echo -e "\n❌ Resultado:"
      echo "   └─ Fallo en la conexión TLS [$VERSION]"
    fi
  done
fi

