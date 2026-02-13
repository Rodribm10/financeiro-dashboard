#!/usr/bin/env python3
"""
Gerar report.json consolidado para o Dashboard Estático
"""

import json
import sys
from datetime import datetime, timedelta
import os

# Arquivos
# Aceitar DATA_ANTERIOR como variável de ambiente, senão calcular
DATA_ANTERIOR = os.environ.get('DATA_ANTERIOR') or (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
ARQUIVO_DADOS = f'/root/mission-control/financeiro/memory/daily/gastos-{DATA_ANTERIOR}.json'
ARQUIVO_SAIDA = '/root/clawd/financeiro-dashboard/report.json'

def gerar_report_json():
    """Gera o report.json consolidado"""
    
    # 1. Ler dados brutos
    print("Lendo dados brutos...")
    try:
        with open(ARQUIVO_DADOS, 'r', encoding='utf-8') as f:
            transacoes = json.load(f)
    except Exception as e:
        print(f"Erro ao ler dados: {e}")
        sys.exit(1)
    
    print(f"{len(transacoes)} transacoes carregadas")
    
    # 2. Agrupar por hotel
    print("Agrupando por hotel...")
    dados_por_hotel = {}
    
    for transacao in transacoes:
        hotel = transacao.get('unidade', 'Desconhecido')
        
        if hotel not in dados_por_hotel:
            dados_por_hotel[hotel] = {
                'total': 0,
                'transactions': []
            }
        
        dados_por_hotel[hotel]['total'] += float(transacao.get('valor', 0))
        dados_por_hotel[hotel]['transactions'].append(transacao)
    
    # 3. Calcular totais globais
    print("Calculando totais...")
    global_total = sum(h['total'] for h in dados_por_hotel.values())
    global_count = sum(len(h['transactions']) for h in dados_por_hotel.values())
    
    # 4. Criar lista de hotéis ordenada
    print("Ordenando hotéis...")
    hoteis_ordenados = []
    
    for hotel, dados in dados_por_hotel.items():
        hotel_entry = {
            'name': hotel,
            'total': dados['total'],
            'count': len(dados['transactions']),
            'transactions': dados['transactions']
        }
        hoteis_ordenados.append(hotel_entry)
    
    # Ordenar por total (maior primeiro)
    hoteis_ordenados.sort(key=lambda x: x['total'], reverse=True)
    
    # 5. Criar estrutura JSON final
    print("Criando JSON final...")
    data_final = {
        'hotels': hoteis_ordenados,
        'global_total': global_total,
        'global_count': global_count,
        'date': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }
    
    # 6. Salvar arquivo
    print(f"Salvando em {ARQUIVO_SAIDA}...")
    try:
        with open(ARQUIVO_SAIDA, 'w', encoding='utf-8') as f:
            json.dump(data_final, f, indent=2, ensure_ascii=False)
        
        print(f"Arquivo salvo: {ARQUIVO_SAIDA}")
        print(f"Total de hotéis: {len(hoteis_ordenados)}")
        print(f"Custo global: R${global_total:.2f}")
        print(f"Total de transações: {global_count}")
        print()
        print("JSON pronto para ser lido pelo dashboard!")
        print()
        print("Próximos passos:")
        print("1. Commit do report.json no GitHub")
        print("2. Commit do index.html (dashboard estático) no GitHub")
        print("3. GitHub Pages vai publicar os dois arquivos")
        print("4. Dashboard vai carregar o report.json automaticamente")
        
    except Exception as e:
        print(f"Erro ao salvar arquivo: {e}")
        sys.exit(1)

if __name__ == '__main__':
    gerar_report_json()
