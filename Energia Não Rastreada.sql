CREATE OR REPLACE FUNCTION calcular_e_armazenar_energia_nao_rastreada(
    ano_input INT,
    cnpj_usuario_input VARCHAR(20)
) RETURNS VOID AS $$

DECLARE
    fe_sin_yearly NUMERIC;
    consumo_localizacao NUMERIC;
    consumo_compra NUMERIC;
    diferenca_consumo NUMERIC;
BEGIN
    -- Deletar dados antigos para evitar duplicação
    DELETE FROM energia_nao_rastreada WHERE ano = ano_input AND cnpj_usuario = cnpj_usuario_input;

    -- Obter FE do SIN Yearly
    SELECT COALESCE("Yearly", 0)
    INTO fe_sin_yearly
    FROM perc_de_etanol_biodiesel_e_de_do_sin
    WHERE "Ano" = ano_input
      AND "Parametros" = 'FE do SIN';

    -- Somar consumo anual e mensal de LOCALIZAÇÃO
    SELECT COALESCE(SUM(consumo_anual), 0) + COALESCE(SUM(consumo_mensal), 0)
    INTO consumo_localizacao
    FROM historico_calcular_emissoes
    WHERE cnpj_usuario = cnpj_usuario_input
      AND EXTRACT(YEAR FROM date) = ano_input
      AND categoria_de_emissoes = 'COMPRA ENERGIA ELÉTRICA - LOCALIZAÇÃO';

    -- Somar consumo anual e mensal de COMPRA
    SELECT COALESCE(SUM(consumo_anual), 0) + COALESCE(SUM(consumo_mensal), 0)
    INTO consumo_compra
    FROM historico_calcular_emissoes
    WHERE cnpj_usuario = cnpj_usuario_input
      AND EXTRACT(YEAR FROM date) = ano_input
      AND categoria_de_emissoes = 'ENERGIA ELETRICA (ESCOLHA DE COMPRA)';

    -- Calcular a diferença entre os dois
    diferenca_consumo := GREATEST(consumo_localizacao - consumo_compra, 0);

    -- Inserir os dados na tabela
    INSERT INTO energia_nao_rastreada (
        cnpj_usuario, ano, 
        consumo_localizacao, consumo_compra, diferenca_consumo, 
        fator_emissao, emissao_total
    ) VALUES (
        cnpj_usuario_input, ano_input, 
        consumo_localizacao, consumo_compra, diferenca_consumo, 
        fe_sin_yearly, diferenca_consumo * fe_sin_yearly
    );

END;
$$ LANGUAGE plpgsql;
