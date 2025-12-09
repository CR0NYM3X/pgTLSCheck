🛡️ **pgTLSCheck.sh** — _Tu escáner experto de seguridad TLS para PostgreSQL_

## 📣 **Descripción de la herramienta**

**pgTLSCheck.sh** es una herramienta de auditoría avanzada en Bash diseñada para realizar pentesting específico sobre la capa TLS/SSL de servidores PostgreSQL. Perfecta para administradores, auditores de seguridad, equipos DevSecOps y profesionales que buscan reforzar la postura criptográfica de su infraestructura de datos. Permite detectar configuraciones inseguras, cipher suites vulnerables, conexiones cifradas, y ahora también realizar escaneos **masivos por IPs** con reportes centralizados en formato CSV.

---

## ✅ **Beneficios clave**

### 1. 🔍 Escaneo de versiones TLS soportadas (`--tls-scan`)
Valida qué versiones del protocolo TLS están habilitadas en el servidor, desde TLS 1.0 hasta TLS 1.3. Ideal para detectar configuraciones obsoletas o protocolos inseguros que deben ser desactivados.

### 2. 🔐 Auditoría de cipher suites (`--tls-supported-ciphers`)
Prueba automaticamente las diferentes negociaciones de cipher suites vulnerables como RC4, MD5, DES, y EXPORT. Detecta ciphers aceptados que representan riesgos críticos, y ofrece claridad sobre qué algoritmos deben eliminarse de la configuración.

### 3. 🌐 Verificación de conexión segura al motor PostgreSQL (`--tls-connect-check`)
Conecta directamente al servidor PostgreSQL, valida la conexión TLS y consulta la vista `pg_stat_ssl` para comprobar si el canal está cifrado correctamente. Recomendado para entornos que exigen cumplimiento en cifrado de datos en tránsito (ej. PCI-DSS, ISO 27001, GDPR).

### 🔐 Funcionalidades 

- **`--csv`**  
  Genera automáticamente un **reporte consolidado en formato CSV** con los resultados por IP escaneada, ideal para auditorías, cumplimiento, y trazabilidad.

- **`--file`**  
  Permite guardar la salida en archivos de texto plano para análisis posterior o integración en sistemas de monitoreo.

- **`--verbose`**  
  Modo resumido que simplifica los resultados, perfecto para automatización o ejecución dentro de scripts externos.



---

## ⚙️ **Características adicionales**

- Modo resumen (`--verbose`) para salidas limpias y automáticas
- Exportación de resultados (`--file`) para generar reportes trazables
- Parámetros flexibles y combinables que permiten escaneos rápidos o completos
- Preparado para integrarse en pipelines de CI/CD o rutinas de monitoreo

---

## 🚀 ¿Por qué usar pgTLSCheck.sh?

🔸 Porque los ataques MITM, la exposición de datos sensibles y las configuraciones inseguras de TLS **son una amenaza real**.  
🔸 Porque PostgreSQL, aunque poderoso, **depende de ti** para asegurar la capa criptográfica.  
🔸 Y porque esta herramienta **automatiza, simplifica y estandariza** el proceso de validación TLS como si tuvieras un auditor de seguridad especializado en cada servidor.
🔹 Evalúa la postura criptográfica de todos tus servidores PostgreSQL en minutos.  
🔹 Detecta configuraciones inseguras antes de que lo hagan los atacantes.  
🔹 Genera evidencias prácticas para tus auditorías de cumplimiento (PCI, ISO, GDPR, SOC2).  
🔹 Centraliza resultados en CSV, ideales para análisis con Excel, dashboards, o SIEMs.

---

**pgTLSCheck.sh** — _Convierte tu PostgreSQL en un bastión cifrado de confianza._


## Ejemplo de uso
 ```
postgres@pruebas-dba /sysx/data16/$ ./pgTLSCheck.sh -h 127.0.0.1 -p 5416 -U postgres -v 0 --tls-connect-check --tls-scan --date-check --tls-supported-ciphers

═════════════════════════════════════════════════════════
📋 Parámetros recibidos:
═════════════════════════════════════════════════════════
• Nivel de verbose:       0
• HOST objetivo:          127.0.0.1
• Puerto:                 5416
• Usuario (DB):           postgres
• Base de datos:          postgres
• Contraseña requerida:   false
• Alcance al servidor:    EXITOSO
• Verificando conexión a PostgreSQL...
   🔐 Conexión SSL exitosa.
    • Detalles SSL:
+-----+---------+------------------------+
| ssl | version |         cipher         |
+-----+---------+------------------------+
| t   | TLSv1.3 | TLS_AES_256_GCM_SHA384 |
+-----+---------+------------------------+
(1 row)
═════════════════════════════════════════════════════════


══════════════════════════════════════════════════════
🔍 Escaneando TLS TLS1 en 127.0.0.1:5416
══════════════════════════════════════════════════════

❌ Resultado:
   • No se pudo establecer conexión TLS (tls1)

🔍 CIPHERS SOPORTADOS: tls1
Cipher                                     | Resultado
-------------------------------------------+-------------

📊 Resumen de Ciphers tls1:
✔ Ciphers aceptados: 0
✘ Ciphers rechazados: 186

⚠ No se logró negociar ningún cipher con TLS tls1.

══════════════════════════════════════════════════════
🔍 Escaneando TLS TLS1_1 en 127.0.0.1:5416
══════════════════════════════════════════════════════

❌ Resultado:
   • No se pudo establecer conexión TLS (tls1_1)

🔍 CIPHERS SOPORTADOS: tls1.1
Cipher                                     | Resultado
-------------------------------------------+-------------

📊 Resumen de Ciphers tls1.1:
✔ Ciphers aceptados: 0
✘ Ciphers rechazados: 186

⚠ No se logró negociar ningún cipher con TLS tls1.1.

══════════════════════════════════════════════════════
🔍 Escaneando TLS TLS1_2 en 127.0.0.1:5416
══════════════════════════════════════════════════════

✅ Resultado (moderno):
   ✔ Conexión exitosa
   • Cipher negociado: ECDHE-RSA-AES256-GCM-SHA384
   • Seguridad avanzada: TLS TLS1_2
   • Subject: C = MX, ST = SINALOA, L = Culiac\C3\A1n, O = dominio_test S.A. de C.V., CN = *.dominio_test.io
   • Issuer: C = US, O = DigiCert Inc, CN = DigiCert Global G2 TLS RSA SHA256 2020 CA1
   • DNS:*.dominio_test.io, DNS:dominio_test.io
📄 Estado del Certificado:
   • Status:         ⚠️ Por expirar
   • Vigencia desde: 11/07/2024 17:00:00
   • Vigencia hasta: 11/07/2025 16:59:59


🔍 CIPHERS SOPORTADOS: tls1.2
Cipher                                     | Resultado
-------------------------------------------+-------------
AES128-CCM                                 | ✔ Conectado
AES128-CCM8                                | ✔ Conectado
AES128-GCM-SHA256                          | ✔ Conectado
AES128-SHA256                              | ✔ Conectado
AES256-CCM                                 | ✔ Conectado
AES256-CCM8                                | ✔ Conectado
AES256-GCM-SHA384                          | ✔ Conectado
AES256-SHA256                              | ✔ Conectado
ARIA128-GCM-SHA256                         | ✔ Conectado
ARIA256-GCM-SHA384                         | ✔ Conectado
CAMELLIA128-SHA256                         | ✔ Conectado
CAMELLIA256-SHA256                         | ✔ Conectado
DHE-RSA-AES128-CCM                         | ✔ Conectado
DHE-RSA-AES128-CCM8                        | ✔ Conectado
DHE-RSA-AES128-GCM-SHA256                  | ✔ Conectado
DHE-RSA-AES128-SHA256                      | ✔ Conectado
DHE-RSA-AES256-CCM                         | ✔ Conectado
DHE-RSA-AES256-CCM8                        | ✔ Conectado
DHE-RSA-AES256-GCM-SHA384                  | ✔ Conectado
DHE-RSA-AES256-SHA256                      | ✔ Conectado
DHE-RSA-ARIA128-GCM-SHA256                 | ✔ Conectado
DHE-RSA-ARIA256-GCM-SHA384                 | ✔ Conectado
DHE-RSA-CAMELLIA128-SHA256                 | ✔ Conectado
DHE-RSA-CAMELLIA256-SHA256                 | ✔ Conectado
DHE-RSA-CHACHA20-POLY1305                  | ✔ Conectado
ECDHE-ARIA128-GCM-SHA256                   | ✔ Conectado
ECDHE-ARIA256-GCM-SHA384                   | ✔ Conectado
ECDHE-RSA-AES128-GCM-SHA256                | ✔ Conectado
ECDHE-RSA-AES128-SHA256                    | ✔ Conectado
ECDHE-RSA-AES256-GCM-SHA384                | ✔ Conectado
ECDHE-RSA-AES256-SHA384                    | ✔ Conectado
ECDHE-RSA-CAMELLIA128-SHA256               | ✔ Conectado
ECDHE-RSA-CAMELLIA256-SHA384               | ✔ Conectado
ECDHE-RSA-CHACHA20-POLY1305                | ✔ Conectado

📊 Resumen de Ciphers tls1.2:
✔ Ciphers aceptados: 34
✘ Ciphers rechazados: 152

══════════════════════════════════════════════════════
🔍 Escaneando TLS TLS1_3 en 127.0.0.1:5416
══════════════════════════════════════════════════════

✅ Resultado (moderno):
   ✔ Conexión exitosa
   • Cipher negociado: TLS_AES_256_GCM_SHA384
   • Seguridad avanzada: TLS TLS1_3
   • Subject: C = MX, ST = SINALOA, L = Culiac\C3\A1n, O = dominio_test S.A. de C.V., CN = *.dominio_test.io
   • Issuer: C = US, O = DigiCert Inc, CN = DigiCert Global G2 TLS RSA SHA256 2020 CA1
   • DNS:*.dominio_test.io, DNS:dominio_test.io
📄 Estado del Certificado:
   • Status:         ⚠️ Por expirar
   • Vigencia desde: 11/07/2024 17:00:00
   • Vigencia hasta: 11/07/2025 16:59:59


🔍 CIPHERS SOPORTADOS: tls1.3
Cipher                                     | Resultado
-------------------------------------------+-------------
TLS_AES_128_CCM_SHA256                     | ✔ Conectado
TLS_AES_128_GCM_SHA256                     | ✔ Conectado
TLS_AES_256_GCM_SHA384                     | ✔ Conectado
TLS_CHACHA20_POLY1305_SHA256               | ✔ Conectado

📊 Resumen de Ciphers tls1.3:
✔ Ciphers aceptados: 4
✘ Ciphers rechazados: 182

 ```


 
