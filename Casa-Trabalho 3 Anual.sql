--drop function calcular_trabalho_casa_3_anual
CREATE OR REPLACE FUNCTION calcular_trabalho_casa_3_anual(
    categoria_emissao_input TEXT,
    tipo_veiculo_frota_input NUMERIC,
    ano_frota_input INT,
    dias_trabalhados_no_ano NUMERIC,
    meses_trabalhados NUMERIC,
    consumo_medio_dia_input NUMERIC,
    date_input DATE,
    ida_volta BOOLEAN
) RETURNS TABLE (
    consumo_fossil NUMERIC,
    consumo_biocombustivel NUMERIC,
    fator_co2 NUMERIC,
    fator_co2_biogenico NUMERIC,
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    emissao_co2 NUMERIC,
    emissao_co2_biogenico NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    composicao_fossil TEXT;
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
    tipo_veiculo TEXT;
BEGIN

        consumo_usado := dias_trabalhados_no_ano * meses_trabalhados * 4;

        -- Obter fatores de emissão de CO₂ e nome do veículo
        SELECT co2_fossil, co2_biocombustivel, veiculo
        INTO co2_fossil_factor, co2_biocombustivel_factor, tipo_veiculo
        FROM lista_veiculos_e_seus_combustiveis
        WHERE id = tipo_veiculo_frota_input;

        -- Buscar consumo médio e o tipo de veículo associado
        EXECUTE format(
            'SELECT "%s", unidade FROM consumo_medio WHERE "veiculo" = %L',
            CASE WHEN ano_frota_input <= 2000 THEN 'até 2000' ELSE ano_frota_input::TEXT END,
            tipo_veiculo
        ) INTO consumo_medio, composicao_fossil;

        IF composicao_fossil = 'km / kWh' THEN
            -- Caso especial: unidade é elétrica
            DECLARE
                fe_sin_anual NUMERIC;
                ano_input INT := EXTRACT(YEAR FROM date_input);
            BEGIN
                EXECUTE format(
                    'SELECT "Yearly" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %s',
                    'FE do SIN', ano_input
                ) INTO fe_sin_anual;

                consumo_calculado := consumo_usado * consumo_medio_dia_input / consumo_medio;
                emissao_co2:= ROUND(consumo_calculado * fe_sin_anual / 1000, 6);

                RETURN QUERY
                SELECT
                    consumo_calculado, CAST(NULL AS NUMERIC), CAST(NULL AS NUMERIC), CAST(NULL AS NUMERIC), CAST(NULL AS NUMERIC), CAST(NULL AS NUMERIC),
                    emissao_co2, -- emissao_co2
                    0::NUMERIC, 0::NUMERIC, 0::NUMERIC, emissao_co2; -- somente CO₂, sem CH₄/N₂O
                RETURN;
            END;
        END IF;

        consumo_calculado := consumo_usado * consumo_medio_dia_input / consumo_medio;

        mes_nome := 'Yearly';

        -- Buscar percentuais de etanol e biodiesel
        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de etanol na gasolina'
        ) INTO perc_etanol;

        EXECUTE format(
            'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L',
            mes_nome, 'Perc. de Biodiesel no Diesel'
        ) INTO perc_biodiesel;

        EXECUTE format(
            'SELECT "%I" FROM lista_veiculos_e_seus_combustiveis WHERE "id" = %s',
            'fossil', tipo_veiculo_frota_input
        ) INTO composicao_fossil;

        -- Calcular consumo
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

        -- Buscar fatores de emissão de CH₄ e N₂O usando o tipo de veículo
        EXECUTE format(
            'SELECT "%s" FROM emissao_ch4_combustivel_movel WHERE "tipo_veiculo" = %L',
            CASE WHEN ano_frota_input <= 2000 THEN 'ate 2000' ELSE ano_frota_input::TEXT END,
            tipo_veiculo
        ) INTO ch4_fossil_factor;

        EXECUTE format(
            'SELECT "%s" FROM emissao_n2o_combustivel_movel WHERE "tipo_veiculo" = %L',
            CASE WHEN ano_frota_input <= 2000 THEN 'ate 2000' ELSE ano_frota_input::TEXT END,
            tipo_veiculo
        ) INTO n2o_fossil_factor;

        -- Calcular emissões
        emissao_co2 := co2_fossil_factor * consumo_fossil / 1000;
        emissao_co2_biogenico := co2_biocombustivel_factor * consumo_biocombustivel / 1000;
        emissao_ch4 := ch4_fossil_factor * consumo_calculado / 1000;
        emissao_n2o := n2o_fossil_factor * consumo_calculado / 1000;
        emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

        IF ida_volta then   
            emissao_total := emissao_total * 2;
            emissao_co2 := emissao_co2 * 2;
            emissao_ch4 := emissao_ch4 * 2;
            emissao_n2o := emissao_n2o * 2;
            consumo_fossil := consumo_fossil * 2;
            consumo_biocombustivel := consumo_biocombustivel * 2;
            emissao_co2_biogenico := emissao_co2_biogenico * 2;
        END if;

        RETURN QUERY
        SELECT consumo_fossil, consumo_biocombustivel, co2_fossil_factor, co2_biocombustivel_factor, ch4_fossil_factor, n2o_fossil_factor,
               emissao_co2, emissao_co2_biogenico, emissao_ch4, emissao_n2o, emissao_total;
END;
$$ LANGUAGE plpgsql;
