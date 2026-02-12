#!/bin/bash
#
# gerar_relatorio_supabase_com_telegram.sh
# Coleta dados do Supabase, gera o dashboard e envia para o Telegram
# Executado pelo Crontab às 10:00 (UTC) -> 13:00 (BRT)
#

echo "============================================================================="
echo "📊 GERANDO RELATÓRIO FINANCEIRO (SUPABASE → DASHBOARD → TELEGRAM)"
echo "============================================================================="
echo "Horário: $(date '+%d/%m/%Y %H:%M:%S UTC')"
echo "============================================================================="

# 1. Configuração
source ~/mission-control/financeiro/config/supabase.env

DATA_ANTERIOR=$(date -d "1 day ago" +%Y-%m-%d)
DATA_ATUAL=$(date +%Y-%m-%d)

ARQUIVO_DADOS="/root/mission-control/financeiro/memory/daily/gastos-${DATA_ANTERIOR}.json"
REPO_DIR="/root/clawd/financeiro-dashboard"

echo "📅 Data de Referência: $DATA_ANTERIOR"
echo "📁 Arquivo de saída: $ARQUIVO_DADOS"
echo ""

# 2. Coletar dados do Supabase
echo "🔍 [1/5] Coletando dados do Supabase..."
RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/get_gastos_dia_anterior" \
  -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"org_id\": \"${ORGANIZATION_ID}\"}")

# Verificar se retornou dados
if [ -z "$RESPONSE" ]; then
    echo "❌ ERRO: Resposta vazia do Supabase"
    exit 1
fi

# Validar JSON
if ! echo "$RESPONSE" | python3 -m json.tool > /dev/null 2>&1; then
    echo "❌ ERRO: Resposta inválida do Supabase"
    echo "$RESPONSE"
    exit 1
fi

# Verificar se tem transações
NUM_TRANSACOES=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data))")
echo "✅ $NUM_TRANSACOES transações encontradas"

if [ "$NUM_TRANSACOES" -eq 0 ]; then
    echo "⚠️ AVISO: Nenhuma transação encontrada para $DATA_ANTERIOR"
    echo "💡 O relatório não será gerado"
    exit 0
fi

# 3. Salvar arquivo JSON
echo ""
echo "💾 [2/5] Salvando arquivo JSON..."
echo "$RESPONSE" > "$ARQUIVO_DADOS"
echo "✅ Arquivo salvo: $ARQUIVO_DADOS"

# 4. Atualizar script gerar_report_json.py para usar o arquivo correto
echo ""
echo "🔨 [3/5] Preparando para gerar dashboard..."

# 5. Executar script Python para gerar report.json
echo ""
echo "📊 [4/5] Gerando report.json..."
cd "$REPO_DIR" || { echo "❌ Erro ao entrar no repositório"; exit 1; }

python3 gerar_report_json.py

if [ $? -ne 0 ]; then
    echo "❌ ERRO ao gerar report.json"
    exit 1
fi

echo "✅ report.json gerado com sucesso"

# 6. Fazer commit e push no Git
echo ""
echo "📤 [5/6] Enviando para o GitHub..."

git add report.json > /dev/null 2>&1

# Verificar se há mudanças
git_status=$(git status --porcelain report.json)

if [ -z "$git_status" ]; then
    echo "⚠️ Nenhuma alteração em report.json (mesmo que o dia anterior)"
else
    # Commit
    MENSAGEM="Update: Relatório diário do dia $DATA_ANTERIOR (via Supabase)

- Dados coletados via RPC get_gastos_dia_anterior
- $NUM_TRANSACOES transações
- Data do relatório: $DATA_ANTERIOR
- Gerado automaticamente às 10:00 UTC (13:00 BRT)"

    git commit -m "$MENSAGEM" --quiet > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "❌ ERRO ao fazer commit"
        exit 1
    fi

    # Push
    git push origin main --quiet > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "❌ ERRO ao fazer push para o GitHub"
        exit 1
    fi

    echo "✅ Push realizado com sucesso"
fi

# 7. Enviar resumo para o Telegram
echo ""
echo "📱 [6/6] Enviando resumo para o Telegram..."

# Gerar e enviar resumo compacto
export DATA_RELATORIO=$DATA_ANTERIOR
python3 << 'PYEOF'
import json
from collections import defaultdict
from datetime import datetime
import requests
import os

# Credenciais do Telegram
BOT_TOKEN = "8281825181:AAHUoYGdg7iUKtQoPzFxlsjpqIKGv_bQu28"
CHAT_ID = "-1003758835428"  # Grupo Squad financeiro

# Obter data do relatório da variável de ambiente
data_ontem = os.environ.get('DATA_RELATORIO', datetime.now().strftime('%Y-%m-%d'))
arquivo_json = '/root/mission-control/financeiro/memory/daily/gastos-{}.json'.format(data_ontem)

with open(arquivo_json, 'r') as f:
    transacoes = json.load(f)

# Agrupar por hotel
por_unidade = defaultdict(list)
for t in transacoes:
    por_unidade[t['unidade']].append(t)

total_geral = sum(g['valor'] for g in transacoes)
num_transacoes = len(transacoes)

# Top hotéis por gasto
top_hoteis = sorted(por_unidade.items(), key=lambda x: sum(g['valor'] for g in x[1]), reverse=True)[:5]

# Gerar resumo
resumo = """📊 RELATÓRIO FINANCEIRO - {}

💰 TOTAL: R$ {:,.2f}
📝 TRANSAÇÕES: {}
🏨 HOTÉIS: {}

━━━━━━━━━━━━━━━━━━━━━

TOP HOTÉIS:
""".format(data_ontem, total_geral, num_transacoes, len(por_unidade))

for i, (unidade, gastos) in enumerate(top_hoteis, 1):
    total_unidade = sum(g['valor'] for g in gastos)
    num_items = len(gastos)
    resumo += "\n{}. {} - R$ {:,.2f} ({} transações)".format(i, unidade, total_unidade, num_items)

resumo += """
━━━━━━━━━━━━━━━━━━━━━

📱 DASHBOARD: https://rodribm10.github.io/financeiro-dashboard/

🤖 Enviado automaticamente pelo Squad Financeiro
📅 Data do relatório: {}
""".format(data_ontem)

# Enviar para o Telegram
url = "https://api.telegram.org/bot{}/sendMessage".format(BOT_TOKEN)
payload = {
    "chat_id": CHAT_ID,
    "text": resumo,
    "parse_mode": "Markdown"
}

try:
    response = requests.post(url, json=payload, timeout=10)
    
    if response.status_code == 200:
        data = response.json()
        if data.get('ok'):
            print("✅ Relatório enviado para o Telegram com sucesso!")
            print("📋 Message ID: {}".format(data.get('result', {}).get('message_id', 'N/A')))
        else:
            print("❌ Erro na API do Telegram: {}".format(data.get('description', 'Erro desconhecido')))
    else:
        print("❌ Erro HTTP {}: {}".format(response.status_code, response.text))
except Exception as e:
    print("❌ Erro ao enviar para o Telegram: {}".format(str(e)))

PYEOF

echo ""

# 8. Exibir resumo final
echo "============================================================================="
echo "🎉 RELATÓRIO FINANCEIRO GERADO COM SUCESSO!"
echo "============================================================================="
echo ""
echo "📅 Data de Referência: $DATA_ANTERIOR"
echo "📊 Total de Transações: $NUM_TRANSACOES"
echo ""

# Calcular total
TOTAL=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
total = sum(item['valor'] for item in data)
print('R\$ {:,.2f}'.format(total))
")

echo "💰 Valor Total: $TOTAL"
echo ""
echo "============================================================================="
echo "✅ PROCESSO CONCLUÍDO!"
echo "============================================================================="
echo ""
echo "📤 Resumo enviado automaticamente para o Telegram"
echo "📱 Dashboard atualizado: https://rodribm10.github.io/financeiro-dashboard/"
