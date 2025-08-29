--drop function compra_energia_localizacao
CREATE OR REPLACE FUNCTION compra_energia_localizacao(
    categoria_emissao_input TEXT,
    consumo_mensal_input NUMERIC,
    consumo_anual_input NUMERIC,
    date_input DATE
) RETURNS TABLE (
    total_emissao NUMERIC,
    fe_sin NUMERIC,
    consumo_mensal NUMERIC,
    consumo_anual NUMERIC
) AS $$
DECLARE
    mes_nome TEXT;
    consumo_usado NUMERIC;
    ano_input INT;
BEGIN
    -- Verificar se a categoria de emissão é "COMPRA ENERGIA ELÉTRICA - LOCALIZAÇÃO"
    IF categoria_emissao_input = 'COMPRA ENERGIA ELÉTRICA - LOCALIZAÇÃO' THEN
        -- Determinar o ano a partir do campo 'date_input'
        SELECT EXTRACT(YEAR FROM date_input)::INT INTO ano_input;

        -- Determinar o valor de consumo a ser usado
        IF consumo_mensal_input = 0 or consumo_mensal_input is null THEN
            consumo_usado := consumo_anual_input;

            -- Buscar o Fator de Emissão Anual para o FE do SIN, considerando o ano
            SELECT "Yearly"
            INTO fe_sin
            FROM perc_de_etanol_biodiesel_e_de_do_sin
            WHERE "Parametros" = 'FE do SIN'
              AND "Ano" = ano_input;

        ELSE
            consumo_usado := consumo_mensal_input;

            -- Obter o nome do mês baseado no campo 'date_input'
            SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;

            -- Buscar o Fator de Emissão Mensal para o FE do SIN, considerando o ano
            EXECUTE format(
                'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %L',
                mes_nome, 'FE do SIN', ano_input
            ) INTO fe_sin;
        END IF;

        -- Calcular emissão total com base no consumo e no Fator de Emissão e retornar junto com fe_sin
        RETURN QUERY
        SELECT consumo_usado * fe_sin, fe_sin, consumo_mensal_input, consumo_anual_input;

    ELSIF categoria_emissao_input = 'COMPRA ENERGIA ELÉTRICA - LOCALIZAÇÃO - COLOMBIA' THEN
        SELECT EXTRACT(YEAR FROM date_input)::INT INTO ano_input;

        -- Determinar o valor de consumo a ser usado
        IF consumo_mensal_input = 0 or consumo_mensal_input is null THEN
            consumo_usado := consumo_anual_input;

            -- Buscar o Fator de Emissão Anual para o FE do SIN, considerando o ano
            SELECT "Yearly"
            INTO fe_sin
            FROM perc_de_etanol_biodiesel_e_de_do_sin
            WHERE "Parametros" = 'FE do SIN (Colombia)'
              AND "Ano" = ano_input;

        ELSE
            consumo_usado := consumo_mensal_input;

            -- Obter o nome do mês baseado no campo 'date_input'
            SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;

            -- Buscar o Fator de Emissão Mensal para o FE do SIN, considerando o ano
            EXECUTE format(
                'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %L',
                mes_nome, 'FE do SIN (Colombia)', ano_input
            ) INTO fe_sin;
        END IF;

        -- Calcular emissão total com base no consumo e no Fator de Emissão e retornar junto com fe_sin
        RETURN QUERY
        SELECT consumo_usado * fe_sin, fe_sin, consumo_mensal_input, consumo_anual_input;
    ELSE
        -- Caso a categoria de emissão não seja válida, retornar NULL
        RETURN QUERY SELECT NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
