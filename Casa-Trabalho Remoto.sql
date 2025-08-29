--drop view emissoes_trabalho_remoto
CREATE OR REPLACE FUNCTION emissoes_trabalho_remoto(
    nro_trabalhadores INTEGER,
    dias_trabalhados INTEGER,
    input_date DATE,
    dias_trabalhados_mes INTEGER
)
RETURNS TABLE (
    ano INTEGER,
    consumo_medio NUMERIC,
    fator_emissao NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    consumo_medio_trabalhador CONSTANT NUMERIC := 150;
    ano_input INTEGER;
    fator NUMERIC;
BEGIN

    if dias_trabalhados_mes is NULL or dias_trabalhados_mes = 0 then
        dias_trabalhados_mes := 230;
    end if;
    -- Extrai o ano da data
    ano_input := EXTRACT(YEAR FROM input_date);

    -- Calcula o consumo médio
    consumo_medio := nro_trabalhadores * consumo_medio_trabalhador * dias_trabalhados_mes / 5 * dias_trabalhados * 8 / 1e6;

    -- Busca o fator de emissão correspondente ao ano
    SELECT p."Yearly"
    INTO fator
    FROM perc_de_etanol_biodiesel_e_de_do_sin p
    WHERE p."Ano" = ano_input AND p."Parametros" = 'FE do SIN'
    LIMIT 1;

    -- Define os retornos
    RETURN QUERY SELECT
        ano_input,
        consumo_medio,
        fator,
        ROUND(consumo_medio * fator, 6) AS emissao_total;
END;
$$ LANGUAGE plpgsql;
