CREATE OR REPLACE FUNCTION calcular_combustao_movel_1(
    categoria_emissao_input TEXT,
    tipo_veiculo_frota_input BIGINT,
    ano_frota_input INT,
    consumo_mensal_input NUMERIC,
    consumo_anual_input NUMERIC,
    date_input DATE
) RETURNS TABLE (
    consumo_fossil NUMERIC,
    consumo_biocombustivel NUMERIC,
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    emissao_co2_biogenico NUMERIC,
    fator_co2 NUMERIC,
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    fator_co2_biogenico NUMERIC,
    biocombustivel_utilizado TEXT,
    combustivel_fossil_utilizado TEXT,
    veiculo_input_id TEXT
) AS $$
DECLARE
    composicao_biocombustivel TEXT;
    composicao_fossil TEXT;
    perc_etanol NUMERIC;
    perc_biodiesel NUMERIC;
    consumo_usado NUMERIC;
    co2_fossil_factor NUMERIC;            -- Fator CO2 fóssil
    co2_biocombustivel_factor NUMERIC;    -- Fator CO2 biogênico
    ch4_fossil_factor NUMERIC;            -- Fator CH4
    n2o_fossil_factor NUMERIC;            -- Fator N2O
    mes_nome TEXT;
    tipo_veiculo_nome TEXT;
BEGIN

    -- Determinar o valor de consumo a ser usado
    IF consumo_mensal_input = 0 or consumo_mensal_input is NULL THEN
        consumo_usado := consumo_anual_input;
        mes_nome := 'Yearly';
    ELSE
        consumo_usado := consumo_mensal_input;
        SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;
    END IF;

    -- Obter o nome do mês baseado no campo 'date_input'
    SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;

    IF tipo_veiculo_frota_input = 48 THEN
            -- Buscar percentuais de etanol e biodiesel dinamicamente da Colombia
        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de etanol na gasolina (Colombia)'
        ) INTO perc_etanol;

        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de Biodiesel no Diesel (Colombia)'
        ) INTO perc_biodiesel;

    ELSE
        -- Buscar percentuais de etanol e biodiesel dinamicamente
        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de etanol na gasolina'
        ) INTO perc_etanol;

        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de Biodiesel no Diesel'
        ) INTO perc_biodiesel;
    END IF;

    SELECT "fossil", "biocombustivel"
    INTO composicao_fossil, composicao_biocombustivel
    FROM lista_veiculos_e_seus_combustiveis
    WHERE id = tipo_veiculo_frota_input::bigint;

    -- Obter composição do combustível do veículo
    SELECT "veiculo" INTO tipo_veiculo_nome
    FROM lista_veiculos_e_seus_combustiveis
    WHERE "id" = tipo_veiculo_frota_input;

    -- Definir o consumo de combustível fóssil baseado na composição
    CASE 
        WHEN composicao_fossil = 'Óleo Diesel (puro)' THEN 
            consumo_fossil := consumo_usado * (1 - perc_biodiesel);
        WHEN composicao_fossil = 'Gasolina Automotiva (pura)' THEN 
            consumo_fossil := consumo_usado * (1 - perc_etanol);
        WHEN composicao_fossil = 'Gás Natural Veicular (GNV)' THEN 
            consumo_fossil := consumo_usado;
        ELSE 
            consumo_fossil := 0;
    END CASE;

    -- Calcular consumo fóssil e biocombustível
    consumo_biocombustivel := consumo_usado - consumo_fossil;

    -- Obter fatores de emissão de CO2 da tabela lista_veiculos_e_seus_combustiveis
    SELECT co2_fossil, co2_biocombustivel
    INTO co2_fossil_factor, co2_biocombustivel_factor
    FROM lista_veiculos_e_seus_combustiveis
    WHERE id = tipo_veiculo_frota_input;

    -- Obter fatores de emissão de CH4 e N2O das tabelas emissao_ch4_combustivel_movel e emissao_n2o_combustivel_movel
    EXECUTE format(
        'SELECT "%s" FROM emissao_ch4_combustivel_movel WHERE "tipo_veiculo" = %L',
        CASE 
            WHEN ano_frota_input <= 2000 THEN 'até 2000'
            ELSE ano_frota_input::TEXT
        END,
        tipo_veiculo_nome
    ) INTO ch4_fossil_factor;

    EXECUTE format(
        'SELECT "%s" FROM emissao_n2o_combustivel_movel WHERE "tipo_veiculo" = %L',
        CASE 
            WHEN ano_frota_input <= 2000 THEN 'até 2000'
            ELSE ano_frota_input::TEXT
        END,
        tipo_veiculo_nome
    ) INTO n2o_fossil_factor;

    -- Calcular emissões
    emissao_co2 := co2_fossil_factor * consumo_fossil / 1000;
    emissao_co2_biogenico := co2_biocombustivel_factor * consumo_biocombustivel / 1000; -- Emissão CO2 Biogênico
    emissao_ch4 := ch4_fossil_factor * consumo_usado / 1000; 
    emissao_n2o := n2o_fossil_factor * consumo_usado / 1000; 

    -- Calcular emissão total
    emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

    RETURN QUERY
    SELECT 
        consumo_fossil, 
        consumo_biocombustivel, 
        emissao_co2, 
        emissao_ch4, 
        emissao_n2o, 
        emissao_total, 
        emissao_co2_biogenico, 
        co2_fossil_factor, 
        ch4_fossil_factor, 
        n2o_fossil_factor, 
        co2_biocombustivel_factor,
        composicao_biocombustivel,
        composicao_fossil, 
        tipo_veiculo_nome;
END;
$$ LANGUAGE plpgsql;
