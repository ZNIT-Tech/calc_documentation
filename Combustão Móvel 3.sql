CREATE OR REPLACE FUNCTION calcular_combustao_movel_3(
    categoria_emissao_input TEXT,
    tipo_veiculo_frota_input NUMERIC,
    ano_frota_input INT,
    ano_de_veculo_input TEXT,
    distancia_mensal_input NUMERIC,
    distancia_anual_input NUMERIC,
    date_input DATE
) RETURNS TABLE (
    consumo_fossil NUMERIC,
    consumo_biocombustivel NUMERIC,
    emissao_co2 NUMERIC,
    emissao_co2_biogenico NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    fator_co2 NUMERIC,
    fator_co2_biogenico NUMERIC,
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    biocombustivel_utilizado TEXT,
    combustivel_fossil_utilizado TEXT
) AS $$
DECLARE
    composicao_biocombustivel TEXT;
    composicao_fossil TEXT;
    ano_frota_utilizado TEXT;
    consumo_medio NUMERIC;
    consumo_calculado NUMERIC;
    consumo_usado NUMERIC;
    perc_etanol NUMERIC;
    perc_biodiesel NUMERIC;
    co2_fossil_factor NUMERIC;
    co2_biocombustivel_factor NUMERIC;
    ch4_fossil_factor NUMERIC;
    n2o_fossil_factor NUMERIC;
    mes_nome TEXT;
    tipo_veiculo_nome TEXT;
BEGIN

    IF categoria_emissao_input IN ('COMBUSTÃO MÓVEL 3', 'TRANSPORTE E DISTRIBUIÇÃO (DOWNSTREAM) 4', 'TRANSPORTE E DISTRIBUIÇÃO (UPSTREAM) 4', 'VIAGENS A NEGÓCIOS - AUTOMÓVEIS 3') THEN

        IF tipo_veiculo_frota_input IS NULL THEN
            RETURN QUERY 
                SELECT 
                    0::numeric,         -- consumo_fossil
                    0::numeric,         -- consumo_biocombustivel
                    0::numeric,         -- emissao_co2
                    0::numeric,         -- emissao_co2_biogenico
                    0::numeric,         -- emissao_ch4
                    0::numeric,         -- emissao_n2o
                    0::numeric,         -- emissao_total
                    0::numeric,         -- co2_fossil_factor
                    0::numeric,         -- co2_biocombustivel_factor
                    0::numeric,         -- ch4_fossil_factor
                    0::numeric,         -- n2o_fossil_factor
                    NULL::text,         -- composicao_biocombustivel
                    NULL::text;         -- composicao_fossil
            RETURN; -- <-- Isso encerra a execução da função imediatamente
        END IF;

       IF distancia_mensal_input = 0 or distancia_mensal_input is null THEN
            consumo_usado := distancia_anual_input;
            mes_nome := 'Yearly';
        ELSE
            consumo_usado := distancia_mensal_input;
            SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;
        END IF;

        IF ano_frota_input = 0 or ano_frota_input is null then
            ano_frota_utilizado := ano_de_veculo_input;
        else
            ano_frota_utilizado := ano_frota_input;
        end if;

        SELECT "veiculo" INTO tipo_veiculo_nome
        FROM lista_veiculos_e_seus_combustiveis
        WHERE "id" = tipo_veiculo_frota_input;

        -- Buscar consumo médio do veículo e ano de frota na tabela consumo_medio
        EXECUTE format(
            'SELECT "%s" FROM consumo_medio WHERE "veiculo" = %L',
            CASE WHEN ano_frota_utilizado::INTEGER <= 2000 THEN 'até 2000' ELSE ano_frota_utilizado::TEXT END,
            tipo_veiculo_nome
        ) INTO consumo_medio;

        -- Calcular o consumo usado em litros baseado na distância percorrida
        IF consumo_medio IS NULL OR consumo_medio = 0 THEN
            consumo_calculado := 0;
        ELSE
            consumo_calculado := consumo_usado / consumo_medio;
        END IF;
        
        -- Buscar percentuais de etanol e biodiesel dinamicamente
        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de etanol na gasolina'
        ) INTO perc_etanol;

        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de Biodiesel no Diesel'
        ) INTO perc_biodiesel;

        EXECUTE format(
            'SELECT "fossil", "biocombustivel" FROM lista_veiculos_e_seus_combustiveis WHERE id = %s',
            tipo_veiculo_frota_input
        ) INTO composicao_fossil, composicao_biocombustivel;

        -- Definir o consumo de combustível fóssil baseado na composição
        CASE 
            WHEN composicao_fossil = 'Óleo Diesel (puro)' THEN 
                consumo_fossil := consumo_calculado * (1 - perc_biodiesel);
            WHEN composicao_fossil = 'Gasolina Automotiva (pura)' THEN 
                consumo_fossil := consumo_calculado * (1 - perc_etanol);
            WHEN composicao_fossil = 'Gás Natural Veicular (GNV)' THEN 
                consumo_fossil := consumo_calculado;
            ELSE 
                consumo_fossil := 0;
        END CASE;

        consumo_biocombustivel := consumo_calculado - consumo_fossil;

        -- Obter fatores de emissão de CO2, CH4 e N2O da tabela lista_veiculos_e_seus_combustiveis
        SELECT co2_fossil, co2_biocombustivel
        INTO co2_fossil_factor, co2_biocombustivel_factor
        FROM lista_veiculos_e_seus_combustiveis
        WHERE id = tipo_veiculo_frota_input;

        IF tipo_veiculo_frota_input BETWEEN 17 AND 32 THEN 
            ano_frota_utilizado := 'Todos os anos';

            EXECUTE format(
                'SELECT "%s" FROM emissao_ch4_combustivel_movel WHERE "tipo_veiculo" = %L',
                ano_frota_utilizado,
                tipo_veiculo_nome
            ) INTO ch4_fossil_factor;

            EXECUTE format(
                'SELECT "%s" FROM emissao_n2o_combustivel_movel WHERE "tipo_veiculo" = %L',
                ano_frota_utilizado,
                tipo_veiculo_nome
            ) INTO n2o_fossil_factor;

        ELSE
            -- Obter fatores de emissão de CH4 e N2O das tabelas emissao_ch4_combustivel_movel e emissao_n2o_combustivel_movel
            EXECUTE format(
                'SELECT "%s" FROM emissao_ch4_combustivel_movel WHERE "tipo_veiculo" = %L',
                CASE 
                    WHEN ano_frota_utilizado::INTEGER <= 2000 THEN 'até 2000'
                    ELSE ano_frota_utilizado::TEXT
                END,
                tipo_veiculo_nome
            ) INTO ch4_fossil_factor;

            EXECUTE format(
                'SELECT "%s" FROM emissao_n2o_combustivel_movel WHERE "tipo_veiculo" = %L',
                CASE 
                    WHEN ano_frota_utilizado::INTEGER <= 2000 THEN 'até 2000'
                    ELSE ano_frota_utilizado::TEXT
                END,
                tipo_veiculo_nome
            ) INTO n2o_fossil_factor;
        END IF;
        -- Calcular emissões
        emissao_co2 := co2_fossil_factor * consumo_fossil / 1000;
        emissao_co2_biogenico := co2_biocombustivel_factor * consumo_biocombustivel / 1000;

        emissao_ch4 := ch4_fossil_factor * consumo_calculado / 1000; -- Usar consumo calculado
        emissao_n2o := n2o_fossil_factor * consumo_calculado / 1000; -- Usar consumo calculado

        -- Calcular emissão total
        emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

        RETURN QUERY
        SELECT consumo_fossil, 
               consumo_biocombustivel, 
               emissao_co2, 
               emissao_co2_biogenico, 
               emissao_ch4, 
               emissao_n2o, 
               emissao_total, 
               co2_fossil_factor, 
               co2_biocombustivel_factor, 
               ch4_fossil_factor, 
               n2o_fossil_factor,
               composicao_biocombustivel,
               composicao_fossil; 
    ELSE
        -- Retornar NULLs se a categoria de emissão não for "COMBUSTÃO MÓVEL 3"
        RETURN QUERY SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
