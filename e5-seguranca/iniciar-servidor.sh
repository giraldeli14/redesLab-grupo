#!/bin/sh
ip route del default 2>/dev/null || true
# Rota de VOLTA: sem ela o servidor recebe o pedido e não consegue responder.
ip route add 10.0.10.0/24 via 10.0.20.254
echo "area restrita do sistema" > /srv/index.html

# Versão desprotegida, na porta 8080. Continua no ar de propósito: o trabalho
# é mostrar a diferença entre as duas, não fingir que a insegura não existe.
httpd -f -p 8080 -h /srv &

# Versão protegida por TLS, porta 8443 (certificado autoassinado)
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj /CN=srv \
        -keyout /lab/key.pem -out /lab/cert.pem 2>/dev/null
openssl s_server -accept 8443 -cert /lab/cert.pem -key /lab/key.pem -www -quiet &

wait
