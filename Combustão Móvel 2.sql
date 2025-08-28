CREATE OR REPLACE FUNCTION calcular_combustao_movel_2(
    categoria_emissao_input TEXT,
    id_combustivel_input NUMERIC,
    consumo_mensal_input NUMERIC,
    consumo_anual_input NUMERIC,
    date_input DATE
) RETURNS TABLE (
    consumo_fossil NUMERIC,
    consumo_biocombustivel NUMERIC,
    emissao_co2 NUMERIC,
    emissao_co2_biogenico NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    co2_fossil_factor NUMERIC,
    co2_bio_factor NUMERIC,
    ch4_fossil_factor NUMERIC,
    n2o_fossil_factor NUMERIC,
    ch4_bio_factor NUMERIC,
    n2o_bio_factor NUMERIC,
    biocombustivel_utilizado TEXT,
    combustivel_fossil_utilizado TEXT
) AS $$
DECLARE
    perc_etanol NUMERIC;
    perc_biodiesel NUMERIC;
    combustivel_fossil TEXT;
    combustivel_biocombustivel TEXT;
    co2_fossil_factor NUMERIC;
    co2_bio_factor NUMERIC;
    ch4_fossil_factor NUMERIC;
    n2o_fossil_factor NUMERIC;
    ch4_bio_factor NUMERIC;
    n2o_bio_factor NUMERIC;
    consumo_usado NUMERIC;
    mes_nome TEXT;
    ano_input INT;
BEGIN
    -- Verificar se a categoria de emissão é "COMBUSTÃO MÓVEL 2"
   IF id_combustivel_input = 59 or id_combustivel_input = 60 or id_combustivel_input = 61 THEN --Combustivel da Colombia

            IF consumo_mensal_input = 0 or consumo_mensal_input is null THEN
                consumo_usado := consumo_anual_input;
            ELSE
                consumo_usado := consumo_mensal_input;
            END IF;

            SELECT co2_fossil, ch4_fossil, n2o_fossil
            INTO co2_fossil_factor, ch4_fossil_factor, n2o_fossil_factor
            FROM airtable_combustivel_emissao
            WHERE id = id_combustivel_input;

            emissao_co2 := co2_fossil_factor * consumo_usado / 1000;
            emissao_ch4 := ch4_fossil_factor * consumo_usado / 1000;
            emissao_n2o := n2o_fossil_factor * consumo_usado / 1000;

            emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

        ELSE
            IF consumo_mensal_input = 0 or consumo_mensal_input is null THEN
                consumo_usado := consumo_anual_input;

                SELECT "Yearly" INTO perc_etanol
                FROM perc_de_etanol_biodiesel_e_de_do_sin
                WHERE "Parametros" = 'Perc. de etanol na gasolina';

                SELECT "Yearly" INTO perc_biodiesel
                FROM perc_de_etanol_biodiesel_e_de_do_sin
                WHERE "Parametros" = 'Perc. de Biodiesel no Diesel';
            ELSE
                consumo_usado := consumo_mensal_input;

                SELECT TO_CHAR(date_input, 'FMMonth') INTO mes_nome;
                SELECT EXTRACT(YEAR FROM date_input)::INT INTO ano_input;

                EXECUTE format(
                    'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %L',
                    mes_nome, 'Perc. de etanol na gasolina', ano_input
                ) INTO perc_etanol;

                EXECUTE format(
                    'SELECT "%s" FROM perc_de_etanol_biodiesel_e_de_do_sin WHERE "Parametros" = %L AND "Ano" = %L',
                    mes_nome, 'Perc. de Biodiesel no Diesel', ano_input
                ) INTO perc_biodiesel;

            END IF;      

            -- Obter fatores e combustíveis
            SELECT fossil, biocombustivel, co2_fossil, co2_bio, ch4_fossil, ch4_bio, n2o_fossil, n2o_bio
            INTO combustivel_fossil, combustivel_biocombustivel,
                co2_fossil_factor, co2_bio_factor,
                ch4_fossil_factor, ch4_bio_factor,
                n2o_fossil_factor, n2o_bio_factor
            FROM airtable_combustivel_emissao
            WHERE id = id_combustivel_input;

            -- Calcular consumo fóssil e biocombustível
            IF combustivel_fossil = 'Gasolina Automotiva (pura)' THEN
                consumo_fossil := consumo_usado * (1 - perc_etanol);
                consumo_biocombustivel := consumo_usado * perc_etanol;
            ELSIF combustivel_fossil = 'Óleo Diesel (puro)' THEN
                consumo_fossil := consumo_usado * (1 - perc_biodiesel);
                consumo_biocombustivel := consumo_usado * perc_biodiesel;
            ELSIF combustivel_fossil = '-' THEN
                consumo_fossil := 0;
                consumo_biocombustivel := consumo_usado;
            ELSE
                consumo_fossil := consumo_usado;
                consumo_biocombustivel := 0;
            END IF;

            -- Calcular emissões
            emissao_co2 := co2_fossil_factor * consumo_fossil / 1000;
            emissao_co2_biogenico := co2_bio_factor * consumo_biocombustivel / 1000;

            emissao_ch4 := 
                (ch4_fossil_factor * consumo_fossil / 1000) + 
                (ch4_bio_factor * consumo_biocombustivel / 1000);

            emissao_n2o := 
                (n2o_fossil_factor * consumo_fossil / 1000) + 
                (n2o_bio_factor * consumo_biocombustivel / 1000);

            -- Calcular emissão total
            emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

        END IF; 
        -- Retornar os resultados
        RETURN QUERY 
        SELECT consumo_fossil, consumo_biocombustivel, emissao_co2, emissao_co2_biogenico,
               emissao_ch4, emissao_n2o, emissao_total,
               co2_fossil_factor, co2_bio_factor, ch4_fossil_factor, n2o_fossil_factor, ch4_bio_factor, n2o_bio_factor, combustivel_biocombustivel, combustivel_fossil;
END;
$$ LANGUAGE plpgsql;
