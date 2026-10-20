#!/bin/sh
# Tenta cada réplica com limite curto. Só imprime o que uma réplica realmente respondeu.
REPLICAS="10.0.20.21 10.0.20.22 10.0.20.23"
inicio=$(date +%s)

for ip in $REPLICAS; do
  # trava de segurança: nunca chegar perto dos 5 s
  [ $(( $(date +%s) - inicio )) -ge 4 ] && break

  r=$(timeout 1 wget -q -T 1 -O - "http://$ip:8080/" 2>/dev/null)

  case "$r" in
    replica1|replica2|replica3) echo "$r"; exit 0 ;;
  esac
done

echo INDISPONIVEL
exit 0