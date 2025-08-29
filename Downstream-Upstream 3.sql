--drop function calcular_trans_distribuicao_upstream_3
CREATE OR REPLACE FUNCTION calcular_trans_distribuicao_upstream_3(
    categoria_emissao_input TEXT,
    id_caminhao INT,
    consumo_anual NUMERIC,
    carga_transportada NUMERIC
) RETURNS TABLE (
    fator_co2_diesel NUMERIC,
    fator_ch4_diesel NUMERIC,
    fator_n2o_diesel NUMERIC,
    fator_co2_biodiesel NUMERIC,
    fator_ch4_biodiesel NUMERIC,
    fator_n2o_biodiesel NUMERIC,
    emissao_co2_diesel NUMERIC,
    emissao_ch4_diesel NUMERIC,
    emissao_n2o_diesel NUMERIC,
    emissao_ch4_biodiesel NUMERIC,
    emissao_n2o_biodiesel NUMERIC,
    emissao_total_co2 NUMERIC,
    emissao_total_ch4 NUMERIC,
    emissao_total_n2o NUMERIC,
    perc_biodiesel_anual NUMERIC,
    emissao_co2e NUMERIC,
    emissao_co2_biodiesel NUMERIC
) AS $$
DECLARE
    perc_biodiesel_anual NUMERIC;
    emissao_total_co2 NUMERIC;
BEGIN
    -- Verificar se a categoria é válida
    IF categoria_emissao_input IN ('TRANSPORTE E DISTRIBUIÇÃO (DOWNSTREAM) 3', 'TRANSPORTE E DISTRIBUIÇÃO (UPSTREAM) 3') THEN
        -- Buscar os fatores de emissão
        SELECT co2_diesel, ch4_diesel, n2o_diesel, co2_biodiesel, ch4_biodiesel, n2o_biodiesel
        INTO fator_co2_diesel, fator_ch4_diesel, fator_n2o_diesel, fator_co2_biodiesel, fator_ch4_biodiesel, fator_n2o_biodiesel
        FROM lista_caminhoes
        WHERE id = id_caminhao;

        -- Obter o percentual de biodiesel anual
        SELECT "Yearly" INTO perc_biodiesel_anual
        FROM perc_de_etanol_biodiesel_e_de_do_sin
        WHERE "Parametros" = 'Perc. de Biodiesel no Diesel';

        -- Cálculos das emissões
        emissao_co2_diesel := consumo_anual * carga_transportada * fator_co2_diesel * (1 - perc_biodiesel_anual);
        emissao_co2_biodiesel := consumo_anual * carga_transportada * fator_co2_biodiesel * perc_biodiesel_anual / 1000;

        emissao_ch4_diesel := consumo_anual * carga_transportada * fator_ch4_diesel * (1 - perc_biodiesel_anual);
        emissao_ch4_biodiesel := consumo_anual * carga_transportada * fator_ch4_biodiesel * perc_biodiesel_anual;

        emissao_n2o_diesel := consumo_anual * carga_transportada * fator_n2o_diesel * (1 - perc_biodiesel_anual);
        emissao_n2o_biodiesel := consumo_anual * carga_transportada * fator_n2o_biodiesel * perc_biodiesel_anual;

        emissao_total_ch4 := (emissao_ch4_diesel + emissao_ch4_biodiesel)/1000;
        emissao_total_n2o := (emissao_n2o_diesel + emissao_n2o_biodiesel)/1000;
        emissao_total_co2 := emissao_co2_diesel / 1000;

        emissao_co2e := (emissao_total_co2) + (emissao_total_ch4 * 28) + (emissao_total_n2o * 265);

        -- Retorno dos valores
        RETURN QUERY SELECT
            fator_co2_diesel, fator_ch4_diesel, fator_n2o_diesel,
            fator_co2_biodiesel, fator_ch4_biodiesel, fator_n2o_biodiesel,
            emissao_total_co2, (emissao_ch4_diesel/1000), (emissao_n2o_diesel/1000),
            (emissao_ch4_biodiesel/1000), (emissao_n2o_biodiesel/1000),
            emissao_total_co2, emissao_total_ch4, emissao_total_n2o, perc_biodiesel_anual, emissao_co2e, emissao_co2_biodiesel;
    ELSE
        RETURN QUERY SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
