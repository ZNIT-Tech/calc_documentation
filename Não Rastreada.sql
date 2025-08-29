CREATE OR REPLACE FUNCTION calcular_energia_nao_rastreada(
    ano_input INT,
    cnpj_usuario_input VARCHAR(20)
) RETURNS TABLE (
    cnpj_usuario VARCHAR(20),
    ano INT,
    emissao_total NUMERIC
) AS $$

BEGIN
    RETURN QUERY
    WITH consumo_por_mes AS (
        -- Buscar os consumos mensal e anual para LOCALIZAÇÃO e ESCOLHA DE COMPRA
        SELECT 
            hce.cnpj_usuario,
            EXTRACT(YEAR FROM hce.date)::INTEGER AS ano,
            EXTRACT(MONTH FROM hce.date) AS mes,
            md.unidade_negocio,  -- Agora consideramos unidade_negocio
            COALESCE(hce.consumo_anual, hce.consumo_mensal) AS localizacao_consumo,

            -- Agregar consumo de escolha de compra, agrupado por unidade_negocio
            COALESCE(
                (SELECT SUM(COALESCE(hce2.consumo_anual, hce2.consumo_mensal))
                 FROM historico_calcular_emissoes hce2
                 JOIN "Main_DataNew" md2 ON hce2.id_main_data_new = md2."ID"  -- Corrigido com aspas duplas
                 WHERE hce2.cnpj_usuario = hce.cnpj_usuario
                   AND EXTRACT(YEAR FROM hce2.date) = EXTRACT(YEAR FROM hce.date)
                   AND EXTRACT(MONTH FROM hce2.date) = EXTRACT(MONTH FROM hce.date)
                   AND hce2.categoria_de_emissoes = 'ENERGIA ELETRICA (ESCOLHA DE COMPRA)'
                   AND md2.unidade_negocio = md.unidade_negocio  -- Agora filtramos corretamente por unidade_negocio
                ), 0
            ) AS escolha_consumo
        FROM historico_calcular_emissoes hce
        JOIN "Main_DataNew" md ON hce.id_main_data_new = md."ID"  -- Corrigido com aspas duplas
        WHERE EXTRACT(YEAR FROM hce.date) = ano_input
          AND hce.cnpj_usuario = cnpj_usuario_input
          AND hce.categoria_de_emissoes = 'COMPRA ENERGIA ELÉTRICA - LOCALIZAÇÃO'
    ),
    diferenca_calculada AS (
        -- Calcular a diferença entre LOCALIZAÇÃO e ESCOLHA, garantindo que o mínimo seja 0
        SELECT 
            cpm.cnpj_usuario,
            cpm.ano,
            cpm.mes,
            cpm.unidade_negocio,
            GREATEST(cpm.localizacao_consumo - cpm.escolha_consumo, 0) AS consumo_nao_rastreado
        FROM consumo_por_mes cpm
    ),
    emissao_calculada AS (
        -- Multiplicar pelo FE do SIN correspondente ao mês e somar emissões
        SELECT 
            dcm.cnpj_usuario,
            dcm.ano::INTEGER AS ano,  -- Converte para INTEGER para evitar erro
            SUM(dcm.consumo_nao_rastreado * COALESCE(pds."January", 0)) AS emissao_total
        FROM diferenca_calculada dcm
        LEFT JOIN perc_de_etanol_biodiesel_e_de_do_sin pds
            ON pds."Ano" = dcm.ano
            AND pds."Parametros" = 'FE do SIN'
        GROUP BY dcm.cnpj_usuario, dcm.ano
    )
    SELECT * FROM emissao_calculada;
END;
$$ LANGUAGE plpgsql;
