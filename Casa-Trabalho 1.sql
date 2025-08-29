--drop function calcular_trabalho_casa_1
CREATE OR REPLACE FUNCTION calcular_trabalho_casa_1(
    categoria_emissao_input TEXT,
    tipo_veiculo_frota_input NUMERIC,
    ano_frota_input INT,
    consumo_mensal_input NUMERIC,
    consumo_anual_input NUMERIC,
    consumo_medio_dia NUMERIC,
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
    emissao_total NUMERIC,
    biocombustivel_utilizado TEXT,
    combustivel_fossil_utilizado TEXT
) AS $$
DECLARE
    composto_fossil TEXT;
    composto_bio TEXT;
    perc_etanol NUMERIC;
    perc_biodiesel NUMERIC;
    consumo_usado NUMERIC;
    co2_fossil_factor NUMERIC;
    co2_biocombustivel_factor NUMERIC;
    ch4_fossil_factor NUMERIC;
    n2o_fossil_factor NUMERIC;
    mes_nome TEXT;
BEGIN
    -- Verificar se a categoria de emissão é "Trabalho-Casa 1"
    IF categoria_emissao_input = 'TRABALHO-CASA 1' THEN
        -- Determinar o valor de consumo a ser usado
        IF consumo_mensal_input = 0 THEN
            consumo_usado := consumo_anual_input;
        ELSE
            consumo_usado := consumo_mensal_input;
        END IF;

        -- Obter o nome do mês baseado no campo 'date_input'
        SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;

        -- Buscar percentuais de etanol e biodiesel dinamicamente
        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de etanol na gasolina'
        ) INTO perc_etanol;

        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de Biodiesel no Diesel'
        ) INTO perc_biodiesel;

        -- Calcular consumo fóssil e biocombustível usando consumo_medio_dia
        consumo_fossil := consumo_usado * consumo_medio_dia * (1 - perc_etanol);
        consumo_biocombustivel := consumo_usado * consumo_medio_dia * perc_etanol;

        -- Obter fatores de emissão de CO2 da tabela lista_veiculos_e_seus_combustiveis
        SELECT co2_fossil, co2_biocombustivel, fossil, biocombustivel
        INTO co2_fossil_factor, co2_biocombustivel_factor, composto_fossil, composto_bio
        FROM lista_veiculos_e_seus_combustiveis
        WHERE id = tipo_veiculo_frota_input;

        -- Obter fatores de emissão de CH4 e N2O das tabelas emissao_ch4_combustivel_movel e emissao_n2o_combustivel_movel
        EXECUTE format(
            'SELECT "%s" FROM emissao_ch4_combustivel_movel WHERE "Id" = %s',
            CASE 
                WHEN ano_frota_input <= 2000 THEN 'ate 2000'
                ELSE ano_frota_input::TEXT
            END,
            tipo_veiculo_frota_input
        ) INTO ch4_fossil_factor;

        EXECUTE format(
            'SELECT "%s" FROM emissao_n2o_combustivel_movel WHERE "Id" = %s',
            CASE 
                WHEN ano_frota_input <= 2000 THEN 'ate 2000'
                ELSE ano_frota_input::TEXT
            END,
            tipo_veiculo_frota_input
        ) INTO n2o_fossil_factor;

        -- Calcular emissões
        emissao_co2 := co2_fossil_factor * consumo_fossil / 1000;
        emissao_ch4 := ch4_fossil_factor * (consumo_fossil + consumo_biocombustivel) / 1000;
        emissao_n2o := n2o_fossil_factor * (consumo_fossil + consumo_biocombustivel) / 1000;

        fator_co2 := co2_fossil_factor;
        fator_ch4 := ch4_fossil_factor;
        fator_n2o := n2o_fossil_factor;

        -- Calcular emissão total
        emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

        IF ida_volta then   
            emissao_total := emissao_total * 2;
            emissao_co2 := emissao_co2 * 2;
            emissao_ch4 := emissao_ch4 * 2;
            emissao_n2o := emissao_n2o * 2;
            consumo_fossil := consumo_fossil * 2;
            consumo_biocombustivel := consumo_biocombustivel * 2;
        END if;

        RETURN QUERY
        SELECT consumo_fossil, consumo_biocombustivel, fator_co2, fator_ch4, fator_n2o, emissao_co2, emissao_ch4, emissao_n2o, emissao_total, composto_bio, composto_fossil;
    ELSE
    
        RETURN QUERY SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
