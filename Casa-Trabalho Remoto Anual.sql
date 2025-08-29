--drop function emissoes_trabalho_remoto_anual
CREATE OR REPLACE FUNCTION emissoes_trabalho_remoto_anual(
    nro_trabalhadores INTEGER,
    dias_trabalhados_semana INTEGER,
    meses_trabalhados INTEGER,
    input_date DATE
)
RETURNS TABLE (
    ano INTEGER,
    consumo_medio NUMERIC,
    fator_emissao NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    consumo_medio_trabalhador CONSTANT NUMERIC := 150; -- em Wh por hora
    ano_input INTEGER;
    fator NUMERIC;
BEGIN
    -- Extrai o ano da data
    ano_input := EXTRACT(YEAR FROM input_date);

    -- Calcula o consumo médio em MWh:
    consumo_medio := nro_trabalhadores * consumo_medio_trabalhador * meses_trabalhados * 4 * dias_trabalhados_semana * 8 / 1e6;

    -- Busca o fator de emissão correspondente ao ano
    SELECT p."Yearly"
    INTO fator
    FROM perc_de_etanol_biodiesel_e_de_do_sin p
    WHERE p."Ano" = ano_input AND p."Parametros" = 'FE do SIN'
    LIMIT 1;

    -- Retorna os dados calculados
    RETURN QUERY SELECT
        ano_input,
        consumo_medio,
        fator,
        ROUND(consumo_medio * fator, 6) AS emissao_total;
END;
$$ LANGUAGE plpgsql;
