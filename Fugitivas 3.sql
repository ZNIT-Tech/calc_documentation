CREATE OR REPLACE FUNCTION calcular_emissoes_fugitivas_3(
    categoria_emissao_input TEXT,
    gwp_id_input INT,
    id_equip_refrigerador_input INT,
    uni_novas_carga_input NUMERIC,
    uni_exist_recarga_input NUMERIC,
    uni_disp_capacidade_input NUMERIC
) RETURNS TABLE (
    emissao_total NUMERIC,
    fator_gwp NUMERIC
) AS $$
DECLARE
    equip_value_a NUMERIC;
    equip_value_b NUMERIC;
    equip_value_c NUMERIC;
    equip_value_d NUMERIC;
BEGIN
    -- Verificar se a categoria de emissão é "Emissões Fugitivas 3"
    IF categoria_emissao_input = 'EMISSOES FUGITIVAS 3' THEN
        -- Buscar o fator de emissão (GWP) associado ao gwp_id
        SELECT gwp
        INTO fator_gwp
        FROM lista_gwp
        WHERE id = gwp_id_input;

        -- Buscar os valores associados ao equipamento refrigerador
        SELECT value_a, value_b, value_c, value_d
        INTO equip_value_a, equip_value_b, equip_value_c, equip_value_d
        FROM lista_equipamentos_refrigeradores
        WHERE id = id_equip_refrigerador_input;

        -- Calcular emissão total
        emissao_total := (
            (uni_novas_carga_input * equip_value_a) +
            (uni_exist_recarga_input * equip_value_b) +
            (uni_disp_capacidade_input * equip_value_c * equip_value_d)
        ) * fator_gwp / 1000;

        -- Retornar os valores calculados
        RETURN QUERY SELECT emissao_total, fator_gwp;
    ELSE
        -- Retornar NULL se a categoria não for válida
        RETURN QUERY SELECT NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
