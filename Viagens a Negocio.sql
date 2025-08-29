CREATE OR REPLACE FUNCTION calcular_emissoes_viagens_negocios(
    categoria_emissao_input TEXT,
    tipo_veiculo_input NUMERIC,
    nro_passageiros_input NUMERIC,
    dist_percorrida_input NUMERIC
) RETURNS TABLE (
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    fator_co2 NUMERIC,
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    fator_co2_bio NUMERIC,
    fator_ch4_bio NUMERIC,
    fator_n2o_bio NUMERIC,
    perc_biodiesel NUMERIC,
    emissao_ch4_bio NUMERIC,
    emissao_n2o_bio NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    fator_co2 NUMERIC;
    fator_ch4 NUMERIC;
    fator_n2o NUMERIC;
    fator_co2_bio NUMERIC;
    fator_ch4_bio NUMERIC;
    fator_n2o_bio NUMERIC;
    perc_biodiesel NUMERIC;
    emissao_co2_fossil NUMERIC;
    emissao_ch4_fossil NUMERIC;
    emissao_n2o_fossil NUMERIC;
    emissao_ch4_bio NUMERIC;
    emissao_n2o_bio NUMERIC;
BEGIN
    -- Verificar se a categoria de emissão é "Viagens a Negócios"
    IF categoria_emissao_input = 'VIAGENS A NEGOCIOS' THEN
        -- Buscar percentual de biodiesel anual
        SELECT "Yearly"
        INTO perc_biodiesel
        FROM perc_de_etanol_biodiesel_e_de_do_sin
        WHERE "Parametros" = 'Perc. de Biodiesel no Diesel';

        -- Verificar se o tipo de veículo é Trem ou Metrô
        IF tipo_veiculo_input IN (6, 7, 9, 14) THEN
            -- Buscar o fator de emissão de CO₂ fóssil
            SELECT co2_fossil
            INTO fator_co2
            FROM lista_veiculos_viagens
            WHERE id = tipo_veiculo_input;

            -- Calcular emissões para Trem ou Metrô (apenas CO₂ fóssil)
            emissao_co2 := (nro_passageiros_input * dist_percorrida_input * fator_co2) / 1000000;
            emissao_ch4 := 0; -- Não possui emissões de CH₄
            emissao_n2o := 0; -- Não possui emissões de N₂O
            emissao_total := emissao_co2;

        -- Verificar se o tipo de veículo é Balsa
        ELSIF tipo_veiculo_input IN (3, 4, 5, 11, 12, 13) THEN
            -- Buscar fatores de emissão para CO₂, CH₄ e N₂O
            SELECT co2_fossil, ch4_fossil, n2o_fossil
            INTO fator_co2, fator_ch4, fator_n2o
            FROM lista_veiculos_viagens
            WHERE id = tipo_veiculo_input;

            -- Calcular emissões para Balsas
            emissao_co2 := (fator_co2 * nro_passageiros_input * dist_percorrida_input) / 1000;
            emissao_ch4 := (fator_ch4 * nro_passageiros_input * dist_percorrida_input) / 1000;
            emissao_n2o := (fator_n2o * nro_passageiros_input * dist_percorrida_input) / 1000;

            -- Calcular emissão total
            emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

        -- Verificar se o tipo de veículo é Ônibus
        ELSIF tipo_veiculo_input IN (1, 2, 8, 10) THEN
            -- Buscar fatores de emissão para combustível fóssil e biocombustível
            SELECT co2_fossil, ch4_fossil, n2o_fossil, co2_bio, ch4_bio, n2o_bio
            INTO fator_co2, fator_ch4, fator_n2o, fator_co2_bio, fator_ch4_bio, fator_n2o_bio
            FROM lista_veiculos_viagens
            WHERE id = tipo_veiculo_input;

            -- Calcular emissões fósseis
            emissao_co2_fossil := (fator_co2 * nro_passageiros_input * dist_percorrida_input * (1 - perc_biodiesel)) / 1000;
            emissao_ch4_fossil := (fator_ch4 * nro_passageiros_input * dist_percorrida_input * (1 - perc_biodiesel)) / 1000;
            emissao_n2o_fossil := (fator_n2o * nro_passageiros_input * dist_percorrida_input * (1 - perc_biodiesel)) / 1000;

            -- Calcular emissões biocombustíveis
            emissao_ch4_bio := (fator_ch4_bio * nro_passageiros_input * dist_percorrida_input * perc_biodiesel) / 1000;
            emissao_n2o_bio := (fator_n2o_bio * nro_passageiros_input * dist_percorrida_input * perc_biodiesel) / 1000;

            -- Somar as emissões de CH₄ e N₂O (fóssil + biocombustível)
            emissao_co2 := emissao_co2_fossil;
            emissao_ch4 := emissao_ch4_fossil + emissao_ch4_bio;
            emissao_n2o := emissao_n2o_fossil + emissao_n2o_bio;

            -- Emissão total
            emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);
            
        ELSE
            -- Retornar NULL para veículos desconhecidos
            RETURN QUERY SELECT NULL::NUMERIC, -- emissao_co2
                NULL::NUMERIC, -- emissao_ch4
                NULL::NUMERIC, -- emissao_n2o
                NULL::NUMERIC, -- fator_co2
                NULL::NUMERIC, -- fator_ch4
                NULL::NUMERIC, -- fator_n2o
                NULL::NUMERIC, -- fator_co2_bio
                NULL::NUMERIC, -- fator_ch4_bio
                NULL::NUMERIC, -- fator_n2o_bio
                NULL::NUMERIC, -- perc_biodiesel
                NULL::NUMERIC, -- emissao_ch4_bio
                NULL::NUMERIC, -- emissao_n2o_bio
                NULL::NUMERIC; -- emissao_total;
        END IF;
    ELSE
        -- Retornar NULL se a categoria de emissão não for "Viagens a Negócios"
        RETURN QUERY SELECT NULL::NUMERIC, -- emissao_co2
                NULL::NUMERIC, -- emissao_ch4
                NULL::NUMERIC, -- emissao_n2o
                NULL::NUMERIC, -- fator_co2
                NULL::NUMERIC, -- fator_ch4
                NULL::NUMERIC, -- fator_n2o
                NULL::NUMERIC, -- fator_co2_bio
                NULL::NUMERIC, -- fator_ch4_bio
                NULL::NUMERIC, -- fator_n2o_bio
                NULL::NUMERIC, -- perc_biodiesel
                NULL::NUMERIC, -- emissao_ch4_bio
                NULL::NUMERIC, -- emissao_n2o_bio
                NULL::NUMERIC; -- emissao_total;
    END IF;

    -- Retornar os valores calculados
    RETURN QUERY SELECT emissao_co2, emissao_ch4, emissao_n2o, fator_co2,
    fator_ch4,
    fator_n2o,
    fator_co2_bio,
    fator_ch4_bio,
    fator_n2o_bio,
    perc_biodiesel,
    emissao_ch4_bio,
    emissao_n2o_bio,emissao_total;
END;
$$ LANGUAGE plpgsql;
