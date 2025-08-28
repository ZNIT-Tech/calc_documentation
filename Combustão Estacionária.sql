--drop function calcular_emissoes_estacionaria
CREATE OR REPLACE FUNCTION calcular_emissoes_estacionaria(
    categoria_emissao_input TEXT,
    combustivel_input NUMERIC,
    id_setor_input INTEGER,
    consumo_anual_input NUMERIC,
    un TEXT,
    date_input DATE
) RETURNS TABLE (
consumo_fossil NUMERIC,
    consumo_biocombustivel NUMERIC,
    emissao_co2_fossil NUMERIC,
    emissao_ch4_fossil NUMERIC,
    emissao_n2o_fossil NUMERIC,
    emissao_co2_bio NUMERIC,
    emissao_ch4_bio NUMERIC,
    emissao_n2o_bio NUMERIC,
    fator_co2_fossil NUMERIC,
    fator_ch4_fossil NUMERIC,
    fator_n2o_fossil NUMERIC,
    fator_co2_bio NUMERIC,
    fator_ch4_bio NUMERIC,
    fator_n2o_bio NUMERIC,
    perc_etanol NUMERIC,
    perc_biodiesel NUMERIC,
    emissao_total NUMERIC,
    biocombustivel_utilizado TEXT,
    combustivel_fossil_utilizado TEXT
) AS $$
DECLARE
    setor_emissao TEXT;
    perc_etanol NUMERIC;
    perc_biodiesel NUMERIC;
    biocombustivel_utilizado TEXT;
    combustivel_fossil_utilizado TEXT;
    co2_fossil_factor NUMERIC;
    co2_biocombustivel_factor NUMERIC;
    ch4_fossil_factor NUMERIC;
    ch4_biocombustivel_factor NUMERIC;
    n2o_fossil_factor NUMERIC;
    n2o_biocombustivel_factor NUMERIC;
    combustivel_utilizado TEXT;
BEGIN

    SELECT setor 
    INTO setor_emissao
    FROM lista_setores_estacionarios
    WHERE id = id_setor_input;

    -- Buscar o combustível utilizado na tabela airtable_combustivel_emissao
    SELECT combustivel, biocombustivel, fossil
    INTO combustivel_utilizado, biocombustivel_utilizado, combustivel_fossil_utilizado
    FROM airtable_combustivel_emissao
    WHERE id = combustivel_input;

    -- Buscar fatores de emissão de CO₂ para combustível fóssil da tabela fator_emissao_fossil_ch4
    EXECUTE format(
        'SELECT COALESCE(co2, 0) FROM fator_emissao_fossil_ch4 WHERE combustivel_fossil = %L',
        combustivel_fossil_utilizado
    ) INTO co2_fossil_factor;

    -- Buscar fatores de emissão de CO₂ para biocombustível da tabela fator_emissao_bio_ch4
    EXECUTE format(
        'SELECT COALESCE(co2, 0) FROM fator_emissao_bio_ch4 WHERE biocombustivel = %L',
        biocombustivel_utilizado
    ) INTO co2_biocombustivel_factor;

    -- Buscar percentuais de etanol e biodiesel (valores anuais)
    EXECUTE format(
        'SELECT COALESCE("Yearly", 0) FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %s', 'Perc. de etanol na gasolina',
        DATE_PART('year', date_input)::TEXT
    ) INTO perc_etanol;

    EXECUTE format(
        'SELECT COALESCE("Yearly", 0) FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %s', 'Perc. de Biodiesel no Diesel',
        DATE_PART('year', date_input)::TEXT
    ) INTO perc_biodiesel;

    IF un = 'kg' or un = 'KG' then
        consumo_anual_input := consumo_anual_input / 1000;
    END IF;

    -- Calcular consumo fóssil e biocombustível com base na lógica condicional
    IF combustivel_utilizado = 'Gasolina Automotiva (comercial)' THEN
        consumo_fossil := consumo_anual_input * (1 - perc_etanol);
        consumo_biocombustivel := consumo_anual_input * perc_etanol;
    ELSIF combustivel_utilizado = 'Óleo Diesel (comercial)' THEN
        consumo_fossil := consumo_anual_input * (1 - perc_biodiesel);
        consumo_biocombustivel := consumo_anual_input * perc_biodiesel;
    ELSIF combustivel_fossil_utilizado = '-' THEN
        consumo_fossil := 0;
        consumo_biocombustivel := consumo_anual_input;
    ELSE
        consumo_fossil := consumo_anual_input;
        consumo_biocombustivel := 0;
    END IF;

    -- Buscar fatores de emissão para CH₄ e N₂O para combustível fóssil
    EXECUTE format(
        'SELECT %I FROM fator_emissao_fossil_ch4 WHERE combustivel_fossil = %L',
        setor_emissao,
        combustivel_fossil_utilizado
    ) INTO ch4_fossil_factor;

    EXECUTE format(
        'SELECT %I FROM fator_emissao_fossil_n2o WHERE combustivel_fossil = %L',
        setor_emissao,
        combustivel_fossil_utilizado
    ) INTO n2o_fossil_factor;

    -- Buscar fatores de emissão para CH₄ e N₂O para biocombustível
    EXECUTE format(
        'SELECT %I FROM fator_emissao_bio_ch4 WHERE biocombustivel = %L',
        setor_emissao,
        biocombustivel_utilizado
    ) INTO ch4_biocombustivel_factor;

    EXECUTE format(
        'SELECT %I FROM fator_emissao_bio_n2o WHERE biocombustivel = %L',
        setor_emissao,
        biocombustivel_utilizado
    ) INTO n2o_biocombustivel_factor;

            -- Ajuste para fatores de emissão fósseis
    IF co2_fossil_factor IS NULL THEN
        co2_fossil_factor := 0;
    END IF;

    IF ch4_fossil_factor IS NULL THEN
        ch4_fossil_factor := 0;
    END IF;

    IF n2o_fossil_factor IS NULL THEN
        n2o_fossil_factor := 0;
    END IF;

    -- Ajuste para fatores de emissão biocombustíveis
    IF co2_biocombustivel_factor IS NULL THEN
        co2_biocombustivel_factor := 0;
    END IF;

    IF ch4_biocombustivel_factor IS NULL THEN
        ch4_biocombustivel_factor := 0;
    END IF;

    IF n2o_biocombustivel_factor IS NULL THEN
        n2o_biocombustivel_factor := 0;
    END IF;

    -- Calcular emissões de CO₂, CH₄ e N₂O para fóssil
    emissao_co2_fossil := co2_fossil_factor * consumo_fossil / 1000;
    emissao_ch4_fossil := ch4_fossil_factor * consumo_fossil / 1000;
    emissao_n2o_fossil := n2o_fossil_factor * consumo_fossil / 1000;

    -- Calcular emissões de CO₂, CH₄ e N₂O para biocombustível
    emissao_co2_bio := co2_biocombustivel_factor * consumo_biocombustivel / 1000;
    emissao_ch4_bio := ch4_biocombustivel_factor * consumo_biocombustivel / 1000;
    emissao_n2o_bio := n2o_biocombustivel_factor * consumo_biocombustivel / 1000;

    -- Calcular emissão total
    emissao_total := 
        emissao_co2_fossil + 
        (emissao_ch4_fossil * 28) + 
        (emissao_n2o_fossil * 265) + 
        (emissao_ch4_bio * 28) + 
        (emissao_n2o_bio * 265);

    -- Retornar os valores calculados
    RETURN QUERY
    SELECT 
        consumo_fossil, 
        consumo_biocombustivel, 
        emissao_co2_fossil, 
        emissao_ch4_fossil, 
        emissao_n2o_fossil, 
        emissao_co2_bio, 
        emissao_ch4_bio, 
        emissao_n2o_bio,
        co2_fossil_factor,
        ch4_fossil_factor,
        n2o_fossil_factor,
        co2_biocombustivel_factor,
        ch4_biocombustivel_factor,
        n2o_biocombustivel_factor,
        perc_etanol,
        perc_biodiesel,
        emissao_total,
        biocombustivel_utilizado,
        combustivel_fossil_utilizado;
END;
$$ LANGUAGE plpgsql;
