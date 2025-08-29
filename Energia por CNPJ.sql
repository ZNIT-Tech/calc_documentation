--drop function calcular_emissao_total_por_cnpj_e_ano
CREATE OR REPLACE FUNCTION calcular_emissao_total_por_cnpj_e_ano(
    cnpj_param VARCHAR,
    data_param DATE
)
RETURNS TABLE (
    emissao_total NUMERIC,
    diferenca_consumo NUMERIC,
    fator_emissao NUMERIC
) AS $$
DECLARE
    ano_extrato INTEGER;
    fe_sin_yearly NUMERIC := 0;
    consumo_localizacao NUMERIC := 0;
    consumo_compra NUMERIC := 0;
    diferenca_consumo NUMERIC := 0;
    emissao_nao_rastreada NUMERIC := 0;
    emissao_escolha_compra NUMERIC := 0;
    emissao_total NUMERIC;
BEGIN
    -- Extrai o ano da data recebida
    ano_extrato := EXTRACT(YEAR FROM data_param);

    -- Obter FE do SIN Yearly
    SELECT COALESCE("Yearly", 0)
    INTO fe_sin_yearly
    FROM perc_de_etanol_biodiesel_e_de_do_sin
    WHERE "Ano" = ano_extrato
      AND "Parametros" = 'FE do SIN';

    -- Somar consumo anual e mensal de LOCALIZAÇÃO
    SELECT COALESCE(SUM(hce.consumo_anual), 0) + COALESCE(SUM(hce.consumo_mensal), 0)
    INTO consumo_localizacao
    FROM historico_calcular_emissoes hce
    WHERE hce.cnpj_usuario = cnpj_param
      AND EXTRACT(YEAR FROM hce.date) = ano_extrato
      AND hce.categoria_de_emissoes = 'COMPRA ENERGIA ELÉTRICA - LOCALIZAÇÃO';

    -- Somar consumo anual e mensal de COMPRA
    SELECT COALESCE(SUM(hce.consumo_anual), 0) + COALESCE(SUM(hce.consumo_mensal), 0)
    INTO consumo_compra
    FROM historico_calcular_emissoes hce
    WHERE hce.cnpj_usuario = cnpj_param
      AND EXTRACT(YEAR FROM hce.date) = ano_extrato
      AND hce.categoria_de_emissoes = 'ENERGIA ELETRICA (ESCOLHA DE COMPRA)';

    -- Calcular a diferença entre os dois (GREATEST evita valores negativos)
    diferenca_consumo := GREATEST(consumo_localizacao - consumo_compra, 0);

    -- Calcular a emissão não rastreada
    emissao_nao_rastreada := diferenca_consumo * fe_sin_yearly;

    -- Obtém a soma de emissões da categoria "ENERGIA ELETRICA (ESCOLHA DE COMPRA)" no histórico
    SELECT COALESCE(SUM(hce.emissao_total), 0)
    INTO emissao_escolha_compra
    FROM historico_calcular_emissoes hce
    WHERE hce.cnpj_usuario = cnpj_param 
    AND EXTRACT(YEAR FROM hce.date) = ano_extrato
    AND hce.categoria_de_emissoes = 'ENERGIA ELETRICA (ESCOLHA DE COMPRA)';

    -- Soma os valores obtidos
    emissao_total := emissao_nao_rastreada + emissao_escolha_compra;

    -- Retorna o valor total de emissões
    RETURN QUERY SELECT emissao_total, diferenca_consumo, fe_sin_yearly;
END;
$$ LANGUAGE plpgsql;
