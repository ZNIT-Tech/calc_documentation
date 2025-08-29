--drop function calcular_trabalho_casa_2
CREATE OR REPLACE FUNCTION calcular_trabalho_casa_2(
    categoria_emissao_input TEXT,
    id_combustivel_input NUMERIC,
    consumo_medio_dia_input NUMERIC,
    consumo_mensal_input NUMERIC,
    consumo_anual_input NUMERIC,
    date_input DATE,
    ida_volta BOOLEAN
) RETURNS TABLE (
    consumo_fossil NUMERIC,
    consumo_biocombustivel NUMERIC,
    fator_co2 NUMERIC,
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    perc_etanol NUMERIC;
    perc_biodiesel NUMERIC;
    combustivel_fossil TEXT;
    combustivel_biocombustivel TEXT;
    co2_fossil_factor NUMERIC;
    co2_bio_factor NUMERIC;
    ch4_fossil_factor NUMERIC;
    ch4_bio_factor NUMERIC;
    n2o_fossil_factor NUMERIC;
    n2o_bio_factor NUMERIC;
    consumo_usado NUMERIC;
    mes_nome TEXT;
    ano_input INT;
BEGIN
    IF categoria_emissao_input = 'TRABALHO-CASA 2' THEN
        -- Determinar o consumo usado (mensal ou anual)
        consumo_usado := CASE WHEN consumo_mensal_input = 0 THEN consumo_anual_input ELSE consumo_mensal_input END;

        -- Obter mês e ano
        SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;
        SELECT EXTRACT(YEAR FROM date_input)::INT INTO ano_input;

        -- Buscar percentuais de etanol e biodiesel
        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %L',
            mes_nome, 'Perc. de etanol na gasolina', ano_input
        ) INTO perc_etanol;

        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %L',
            mes_nome, 'Perc. de Biodiesel no Diesel', ano_input
        ) INTO perc_biodiesel;

        -- Buscar combustíveis e fatores de emissão
        SELECT fossil, biocombustivel, co2_fossil, co2_bio, ch4_fossil, ch4_bio, n2o_fossil, n2o_bio
        INTO combustivel_fossil, combustivel_biocombustivel, co2_fossil_factor, co2_bio_factor, ch4_fossil_factor, 
             ch4_bio_factor, n2o_fossil_factor, n2o_bio_factor
        FROM airtable_combustivel_emissao
        WHERE id = id_combustivel_input;

        -- Calcular consumo fóssil e biocombustível
        consumo_fossil := consumo_usado * consumo_medio_dia_input * (1 - COALESCE(perc_etanol, perc_biodiesel));
        consumo_biocombustivel := consumo_usado * consumo_medio_dia_input * COALESCE(perc_etanol, perc_biodiesel);

        -- Calcular emissões
        emissao_co2 := co2_fossil_factor * consumo_fossil / 1000;
        emissao_ch4 := (ch4_fossil_factor * consumo_fossil / 1000) + (ch4_bio_factor * consumo_biocombustivel / 1000);
        emissao_n2o := (n2o_fossil_factor * consumo_fossil / 1000) + (n2o_bio_factor * consumo_biocombustivel / 1000);

        -- Emissão total
        emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);
        
        --Opcao de ida e volta para Lavoro
        IF ida_volta then   
            emissao_total := emissao_total * 2;
            emissao_co2 := emissao_co2 * 2;
            emissao_ch4 := emissao_ch4 * 2;
            emissao_n2o := emissao_n2o * 2;
            consumo_fossil := consumo_fossil * 2;
            consumo_biocombustivel := consumo_biocombustivel * 2;
        END if;

        RETURN QUERY 
        SELECT consumo_fossil, consumo_biocombustivel, co2_fossil_factor, ch4_fossil_factor, n2o_fossil_factor,
               emissao_co2, emissao_ch4, emissao_n2o, emissao_total;
    ELSE
        RETURN QUERY SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
