# Fluxo Completo Automatizado com Telegram

## Novo Fluxo (CORRIGIDO E COMPLETO)

```
📅 07:00 BRT (10:00 UTC)
    ↓
🔍 Coleta dados do Supabase (dia anterior)
    ↓
💾 Gera gastos-YYYY-MM-DD.json
    ↓
📊 Gera report.json
    ↓
📤 Push para GitHub
    ↓
✅ Dashboard atualiza automaticamente
    ↓
📱 Envia resumo para o Telegram ✨ NOVO!
```

## Passos Detalhados

### 1. Coleta de Dados do Supabase
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_gastos_dia_anterior"
```
- Conecta ao Supabase via RPC
- Coleta as transações do dia anterior
- Salva como JSON: `/root/mission-control/financeiro/memory/daily/gastos-YYYY-MM-DD.json`

### 2. Geração do Report
```bash
python3 gerar_report_json.py
```
- Lê o JSON coletado
- Agrupa por hotel
- Calcula totais
- Gera `report.json`

### 3. Commit no Git
```bash
git add report.json
git commit -m "Update: Relatório diário..."
git push origin main
```

### 4. Dashboard Atualiza Automaticamente
- GitHub Pages publica os arquivos
- JavaScript no `index.html` carrega `report.json` via `fetch()`
- Dados são exibidos automaticamente

### 5. Resumo para o Telegram ✨
```python
requests.post(
    f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
    json={
        "chat_id": CHAT_ID,
        "text": resumo,
        "parse_mode": "Markdown"
    }
)
```
- Gera resumo compacto (TOP 5 hotéis)
- Envia automaticamente para o Telegram
- Bot: financeiro_grupo_inova_bot
- Chat ID: 661151076

## Credenciais do Telegram

```python
BOT_TOKEN = "8281825181:AAHUoYGdg7iUKtQoPzFxlsjpqIKGv_bQu28"
CHAT_ID = "661151076"
```

## Mensagem Enviada para o Telegram

```
📊 RELATÓRIO FINANCEIRO - 2026-02-11

💰 TOTAL: R$ 38,390.60
📝 TRANSAÇÕES: 39
🏨 HOTÉIS: 7

━━━━━━━━━━━━━━━━━━━━━

TOP HOTÉIS:

1. Dolce Amore - R$ 22,722.26 (4 transações)
2. Prime AL - R$ 5,278.01 (16 transações)
3. Prime VL - R$ 3,153.58 (5 transações)
4. 1001 Express - R$ 2,830.80 (5 transações)
5. Padova - R$ 2,470.55 (1 transações)

━━━━━━━━━━━━━━━━━━━━━

📱 DASHBOARD: https://rodribm10.github.io/financeiro-dashboard/

🤖 Enviado automaticamente pelo Squad Financeiro
📅 Data do relatório: 2026-02-11
```

## Crontab Atualizado

```bash
# Squad Financeiro - Diário (10:00 UTC / 07:00 BRT)
0 10 * * * /root/clawd/financeiro-dashboard/gerar_relatorio_supabase_com_telegram.sh
```

## Arquivos Envolvidos

```
/root/clawd/financeiro-dashboard/
├── gerar_relatorio_supabase_com_telegram.sh  # Script completo com Telegram
├── index.html                                 # Dashboard dinâmico
├── report.json                                # Dados gerados
└── fluxo_completo.md                          # Esta documentação

/root/mission-control/financeiro/
└── memory/daily/
    └── gastos-YYYY-MM-DD.json                 # Dados brutos do Supabase
```

## Teste Realizado

✅ **14:52 UTC - Teste executado com sucesso**
- Coletou 39 transações do Supabase
- Gerou report.json
- Fez push para GitHub
- **Enviou resumo para o Telegram (Message ID: 91)**

## Próxima Execução Automática

**Amanhã (13/02) às 07:00 BRT**, o fluxo vai:
1. Coletar dados de 12/02 do Supabase
2. Gerar report.json
3. Fazer push para GitHub
4. Atualizar dashboard automaticamente
5. **Enviar resumo para o Telegram** ✨

**Nenhuma intervenção manual necessária!**
