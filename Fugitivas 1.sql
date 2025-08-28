--drop function calcular_emissoes_fugitivas_1
CREATE OR REPLACE FUNCTION calcular_emissoes_fugitivas_1(
    categoria_emissao_input TEXT,
    gwp_id_input INT,
    uni_novas_carga_input NUMERIC,
    uni_novas_capacidade_input NUMERIC,
    uni_exist_recarga_input NUMERIC,
    uni_disp_capacidade_input NUMERIC,
    uni_disp_recup_input NUMERIC
) RETURNS TABLE (
    emissao_total NUMERIC,
    fator_gwp NUMERIC,
    emissoes_hfc NUMERIC,
    emissoes_pfc NUMERIC,
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC
) AS $$
DECLARE
    vazio_contador INT := 0;
    nome_gas TEXT;
    nome_gas_x TEXT;
    percentual NUMERIC;
BEGIN
    -- Buscar nome do gás associado ao gwp_id
    SELECT gas INTO nome_gas
    FROM lista_gwp
    WHERE id = gwp_id_input;

    -- Buscar o fator de emissão (GWP) associado ao gwp_id
    SELECT gwp INTO fator_gwp
    FROM lista_gwp
    WHERE id = gwp_id_input;

    -- Contar campos vazios
    IF uni_novas_capacidade_input IS NULL THEN vazio_contador := vazio_contador + 1; END IF;
    IF uni_exist_recarga_input IS NULL THEN vazio_contador := vazio_contador + 1; END IF;
    IF uni_disp_capacidade_input IS NULL THEN vazio_contador := vazio_contador + 1; END IF;

    -- Calcular emissão total se menos de 3 campos forem vazios
    IF vazio_contador < 3 THEN
        emissao_total := (
            COALESCE(uni_novas_carga_input,0)
            - COALESCE(uni_novas_capacidade_input,0)
            + COALESCE(uni_exist_recarga_input,0)
            + COALESCE(uni_disp_capacidade_input,0)
            - COALESCE(uni_disp_recup_input,0)
        ) * fator_gwp / 1000;
    ELSE
        emissao_total := NULL;
    END IF;

    -- Inicializar emissões
    emissoes_hfc := 0;
    emissoes_pfc := 0;
    emissao_co2 := 0;
    emissao_ch4 := 0;
    emissao_n2o := 0;

    -- Se for CO2, CH4 ou N2O, atribuir diretamente
    IF gwp_id_input = 1 THEN  -- CO2
        emissao_co2 := emissao_total;
    ELSIF gwp_id_input = 2 THEN  -- CH4
        emissao_ch4 := emissao_total;
    ELSIF gwp_id_input = 3 THEN  -- N2O
        emissao_n2o := emissao_total;
    ELSE
        -- Se não for CO2, CH4 ou N2O, buscar gases equivalentes
        FOR nome_gas_x, percentual IN 
            SELECT "Gás 1", "% do Gás 1" FROM equivalencia_gases WHERE "Composto" = nome_gas
            UNION ALL
            SELECT "Gás 2", "% do Gás 2" FROM equivalencia_gases WHERE "Composto" = nome_gas
            UNION ALL
            SELECT "Gás 3", "% do Gás 3" FROM equivalencia_gases WHERE "Composto" = nome_gas
            UNION ALL
            SELECT "Gás 4", "% do Gás 4" FROM equivalencia_gases WHERE "Composto" = nome_gas
            UNION ALL
            SELECT "Gás 5", "% do Gás 5" FROM equivalencia_gases WHERE "Composto" = nome_gas
        LOOP
            -- Verifica se o gás equivalente pertence a HFC ou PFC e calcula
            IF nome_gas_x LIKE 'HFC%' THEN
                emissoes_hfc := emissoes_hfc + (emissao_total / fator_gwp * percentual);
            ELSIF nome_gas_x LIKE 'PFC%' THEN
                emissoes_pfc := emissoes_pfc + (emissao_total / fator_gwp * percentual);
            END IF;
        END LOOP;
    END IF;

    -- Retornar os valores calculados
    RETURN QUERY SELECT emissao_total, fator_gwp, emissoes_hfc, emissoes_pfc, emissao_co2, emissao_ch4, emissao_n2o;
END;
$$ LANGUAGE plpgsql;

