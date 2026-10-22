#!/usr/bin/env bash
# Auto‑git add / commit / push
# Executa este script antes de fechar a aplicação ou sempre que quiseres sincronizar.

set -e

# Verifica se há mudanças
if git status --porcelain | grep .; then
  git add .
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  git commit -m "Auto commit: $TIMESTAMP"
  git push
  echo "✅ Alterações enviadas ao remote."
else
  echo "🔄 Nenhuma alteração a enviar."
fi
