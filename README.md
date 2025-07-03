🛡️ **pgTLSCheck.sh** — _Tu escáner experto de seguridad TLS para PostgreSQL_

## 📣 **Descripción de la herramienta**

**pgTLSCheck.sh** es una herramienta de auditoría avanzada en Bash diseñada para realizar pentesting específico sobre la capa TLS/SSL de servidores PostgreSQL. Perfecta para administradores, auditores de seguridad, equipos DevSecOps y profesionales que buscan reforzar la postura criptográfica de su infraestructura de datos.

---

## ✅ **Beneficios clave**

### 1. 🔍 Escaneo de versiones TLS soportadas (`--tls-scan`)
Valida qué versiones del protocolo TLS están habilitadas en el servidor, desde TLS 1.0 hasta TLS 1.3. Ideal para detectar configuraciones obsoletas o protocolos inseguros que deben ser desactivados.

### 2. 🔐 Auditoría de cipher suites (`--tls-cipher-audit`)
Prueba manualmente la negociación de cipher suites vulnerables como RC4, MD5, DES, y EXPORT. Detecta ciphers aceptados que representan riesgos críticos, y ofrece claridad sobre qué algoritmos deben eliminarse de la configuración.

### 3. 🌐 Verificación de conexión segura al motor PostgreSQL (`--tls-connect-check`)
Conecta directamente al servidor PostgreSQL, valida la conexión TLS y consulta la vista `pg_stat_ssl` para comprobar si el canal está cifrado correctamente. Recomendado para entornos que exigen cumplimiento en cifrado de datos en tránsito (ej. PCI-DSS, ISO 27001, GDPR).

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

---

**pgTLSCheck.sh** — _Convierte tu PostgreSQL en un bastión cifrado de confianza._
 
