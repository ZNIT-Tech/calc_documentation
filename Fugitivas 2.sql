CREATE OR REPLACE FUNCTION calcular_emissoes_fugitivas_2(
    categoria_emissao_input TEXT,
    gwp_id_input INT,
    variacao_estoque NUMERIC,
    quantidade_transferida NUMERIC,
    mudanca_capacidade NUMERIC
) RETURNS TABLE (
    emissao_total NUMERIC,
    fator_gwp NUMERIC
) AS $$
DECLARE
    vazio_contador INT := 0;
BEGIN
    -- Verificar se a categoria de emissão é "Emissões Fugitivas 2"
    IF categoria_emissao_input = 'EMISSOES FUGITIVAS 2' THEN
        -- Buscar o fator de emissão (GWP) associado ao gwp_id
        SELECT gwp
        INTO fator_gwp
        FROM lista_gwp
        WHERE id = gwp_id_input;

        -- Contar campos vazios
        IF variacao_estoque IS NULL THEN vazio_contador := vazio_contador + 1; END IF;
        IF quantidade_transferida IS NULL THEN vazio_contador := vazio_contador + 1; END IF;
        IF mudanca_capacidade IS NULL THEN vazio_contador := vazio_contador + 1; END IF;

        -- Calcular emissão total se menos de 3 campos forem vazios
        IF vazio_contador < 3 THEN
            emissao_total := (
                quantidade_transferida +
                variacao_estoque +
                mudanca_capacidade
            ) * fator_gwp / 1000;
        ELSE
            -- Caso mais de 2 campos sejam vazios, retornar NULL
            emissao_total := NULL;
        END IF;

        -- Retornar os valores calculados
        RETURN QUERY SELECT emissao_total, fator_gwp;
    ELSE
        -- Retornar NULL se a categoria não for válida
        RETURN QUERY SELECT NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
