--drop function calcular_bens_servico
CREATE OR REPLACE FUNCTION calcular_bens_capital(
    id_produto_input NUMERIC,
    quant NUMERIC,
    un_input TEXT,
    fator_de_emissao_bruto NUMERIC,
    fator_correcao_do_fator_emissao NUMERIC,
    fator_conv_un_medida NUMERIC
)
RETURNS TABLE (
    fator_emissao NUMERIC,
    quant_convertida NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    unidade_liquida TEXT;
    fator_de_emissao_liquido NUMERIC;
    densidade NUMERIC;
    quant_convertida_local NUMERIC;
BEGIN
    -- Busca dados do produto, se existir
    IF id_produto_input IS NULL THEN
        fator_de_emissao_liquido := fator_de_emissao_bruto;
    ELSE
        EXECUTE format(
            'SELECT %I, %I, %I FROM fatores_bens_capital WHERE id = %L',
            'fator_emissao',
            'unidade',
            'densidade',
            id_produto_input
        )
        INTO fator_de_emissao_liquido, unidade_liquida, densidade;
    END IF;

    -- Aplicar fator de correção e conversão se não informados
    IF fator_correcao_do_fator_emissao IS NULL OR fator_correcao_do_fator_emissao = 0 THEN
        fator_correcao_do_fator_emissao := 1;
    END IF;

    IF fator_conv_un_medida IS NULL OR fator_conv_un_medida = 0 THEN
        fator_conv_un_medida := 1;
    END IF;

    -- Calcular fator corrigido
    fator_emissao := fator_de_emissao_liquido * fator_correcao_do_fator_emissao;

    -- Aplica fator de conversão
    quant_convertida_local := quant * fator_conv_un_medida;

    -- Ajustar para tonelada
    IF lower(un_input) = 'kg' AND lower(unidade_liquida) = 'kg' THEN
        -- Mesma unidade (kg), conversão no final
        emissao_total := quant_convertida_local * fator_emissao / 1000;

    ELSIF lower(un_input) = 't' AND lower(unidade_liquida) = 't' THEN
        -- Mesma unidade (tonelada), sem conversão extra
        emissao_total := quant_convertida_local * fator_emissao;

    ELSIF lower(un_input) = 't' AND lower(unidade_liquida) = 'kg' THEN
        -- Entrada em toneladas, fator em kg => converter fator
        emissao_total := quant_convertida_local * (fator_emissao / 1000);

    ELSIF lower(un_input) = 'kg' AND lower(unidade_liquida) = 't' THEN
        -- Entrada em kg, fator em toneladas => converter quantidade
        emissao_total := (quant_convertida_local / 1000) * fator_emissao;

    ELSE
        -- Outros casos ou unidade não tratada: aplicar normalmente
        emissao_total := quant_convertida_local * fator_emissao;
    END IF;

    -- Adiciona casos especiais de densidade para unidade líquida
    IF lower(unidade_liquida) = 'm3' THEN
        emissao_total := emissao_total / NULLIF(densidade, 0);
    END IF;

    emissao_total:=emissao_total/1000;

    -- Retornar resultados
    RETURN QUERY SELECT fator_emissao, quant_convertida_local, emissao_total;
END;
$$ LANGUAGE plpgsql;
