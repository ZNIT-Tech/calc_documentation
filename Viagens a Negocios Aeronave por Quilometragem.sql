--DROP FUNCTION calcular_emissoes_aeronave_quilometragem
CREATE OR REPLACE FUNCTION calcular_emissoes_aeronave_quilometragem(
    p_cnpj_usuario TEXT,
    p_dist_percorrida NUMERIC,
    consumo_mensal NUMERIC
) RETURNS TABLE (
    cnpj_usuario TEXT,
    distancia_percorrida TEXT,
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    v_fator_co2 NUMERIC,
    v_fator_ch4 NUMERIC,
    v_fator_n2o NUMERIC
) AS $$
DECLARE
    v_distancia_percorrida TEXT;
    v_acrescimo NUMERIC;
    v_fator_co2 NUMERIC;
    v_fator_ch4 NUMERIC;
    v_fator_n2o NUMERIC;
BEGIN
    -- Determinar a categoria da distância
    IF p_dist_percorrida <= 500 THEN
        v_distancia_percorrida := 'curta';
    ELSIF p_dist_percorrida > 500 AND p_dist_percorrida <= 3700 THEN
        v_distancia_percorrida := 'media';
    ELSE
        v_distancia_percorrida := 'longa';
    END IF;

    -- Obter os fatores de emissão e acréscimo conforme a categoria da distância
    SELECT acrescimo, fator_co2, fator_ch4, fator_n2o
    INTO v_acrescimo, v_fator_co2, v_fator_ch4, v_fator_n2o
    FROM fator_emissao_aviacao_civil
    WHERE distancia = v_distancia_percorrida
    LIMIT 1;

    -- Calcular emissões
    emissao_co2 := (1 + (v_acrescimo/100)) * consumo_mensal * v_fator_co2 / 1000;
    emissao_ch4 := (1 + (v_acrescimo/100)) * consumo_mensal * v_fator_ch4 / 1000;
    emissao_n2o := (1 + (v_acrescimo/100)) * consumo_mensal * v_fator_n2o / 1000;

    -- Calcular emissão total
    emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

    -- Retornar os resultados
    RETURN QUERY SELECT p_cnpj_usuario, v_distancia_percorrida, emissao_co2, emissao_ch4, emissao_n2o, emissao_total, v_fator_co2, v_fator_ch4, v_fator_n2o;
END;
$$ LANGUAGE plpgsql;
