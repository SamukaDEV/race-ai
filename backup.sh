#!/bin/bash

# Captura a data e hora formatada como "Backup DD/MM/AAAA hh:mm:ss"
MENSAGEM="Backup $(date '+%d/%m/%Y %H:%M:%S')"

# Adiciona todas as modificações (arquivos novos, alterados e deletados)
git add -A

# Realiza o commit com a mensagem gerada
git commit -m "$MENSAGEM"

# Exibe a mensagem de sucesso no terminal
echo "✅ Commit realizado com sucesso: $MENSAGEM"
