FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8443

ENV SERVICE_TLS_CERT_FILE=/etc/internal-tls/order-service.crt \
    SERVICE_TLS_KEY_FILE=/etc/internal-tls/order-service.key \
    SERVICE_TLS_CA_CERT=/etc/internal-tls/ca.crt

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port 8443 --ssl-certfile $SERVICE_TLS_CERT_FILE --ssl-keyfile $SERVICE_TLS_KEY_FILE --ssl-ca-certs $SERVICE_TLS_CA_CERT --ssl-cert-reqs 2"]
