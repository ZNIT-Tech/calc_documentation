Etapas do Cálculo
1. Determinação do consumo a ser usado
Se o consumo mensal for zero ou nulo, utiliza-se o valor anual.

O nome do mês é extraído da date_input para uso em consultas dinâmicas.

2. Obtenção dos percentuais de mistura de biocombustível
Se o veículo for colombiano (tipo_veiculo_frota_input = 48), são usados percentuais específicos da Colômbia.

Caso contrário, são usados os percentuais padrão nacionais da tabela perc_de_etanol_biodiesel_e_de_do_sin.

3. Obtenção da composição de combustível do veículo
A tabela lista_veiculos_e_seus_combustiveis informa qual o combustível fóssil e o biocombustível utilizados pelo veículo.

4. Cálculo do consumo de combustível fóssil e biocombustível
Baseado na composição e nos percentuais de mistura:

Diesel puro → aplica percentual de biodiesel.

Gasolina pura → aplica percentual de etanol.

GNV → considerado 100% fóssil.

O consumo de biocombustível é a diferença entre o total e o fóssil.

5. Obtenção dos fatores de emissão
CO₂ (fóssil e biogênico): da tabela lista_veiculos_e_seus_combustiveis.

CH₄ e N₂O:

Tabelas emissao_ch4_combustivel_movel e emissao_n2o_combustivel_movel.

Considera o nome do veículo e o ano da frota (agrupando anos ≤ 2000).

6. Cálculo das emissões
CO₂ (fóssil) = fator_CO2_fossil * consumo_fossil / 1000

CO₂ (biogênico) = fator_CO2_biogenico * consumo_biocombustivel / 1000

CH₄ = fator_CH4 * consumo_total / 1000

N₂O = fator_N2O * consumo_total / 1000

Total = CO₂_fossil + (CH₄ * 28) + (N₂O * 265)

Utiliza-se os Potenciais de Aquecimento Global (GWP): CH₄ = 28 e N₂O = 265.

