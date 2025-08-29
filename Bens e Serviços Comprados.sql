--drop function calcular_emissoes_compra_produtos
CREATE OR REPLACE FUNCTION calcular_emissoes_compra_produtos(
    id_produto_input NUMERIC,
    quant NUMERIC,
    un_input TEXT,
    fator_de_emissao_bruto NUMERIC,
    fator_correcao_do_fator_emissao NUMERIC,
    fator_conv_un_medida NUMERIC,
    cnpj_usuario TEXT
) RETURNS TABLE (
    fator_emissao NUMERIC,
    quant_convertida NUMERIC,
    emissao_total NUMERIC,
    erro_total NUMERIC
) AS $$
DECLARE
    unidade_liquida TEXT;
    fator_de_emissao_liquido NUMERIC;
    quant_convertida_total NUMERIC;
    densidade NUMERIC;
    perc_erro NUMERIC := 0;
    emissao_mitre NUMERIC;
BEGIN

    -- Busca dados do produto, se existir
    IF id_produto_input IS NULL THEN
        fator_de_emissao_liquido := fator_de_emissao_bruto;
    ELSE
        IF trim(cnpj_usuario) = '07882930000165' then
            EXECUTE format(
                'SELECT %I, %I FROM fatores_compra_produto_servicos_mitre WHERE id = %L',
                'fator',  -- Nome da coluna do fator de emissão
                'erro_fator',              
                id_produto_input              -- ID do produto
            ) INTO fator_de_emissao_liquido, perc_erro;

            unidade_liquida:= 't';

            IF id_produto_input = 10 AND lower(un_input) = 'm3' THEN
                un_input := 't';       -- atualiza unidade para o cálculo abaixo
            END IF;

            IF lower(un_input) = 'kg' AND lower(unidade_liquida) = 't' THEN
                emissao_total := (quant / 1000) * fator_de_emissao_liquido;
            ELSIF lower(un_input) = 't' AND lower(unidade_liquida) = 't' THEN
                emissao_total := quant * fator_de_emissao_liquido;
            end if;

            erro_total := emissao_total * perc_erro;
            emissao_mitre = emissao_total;
            RETURN QUERY SELECT fator_de_emissao_liquido, quant, emissao_mitre, erro_total;
            Return;
        else
            EXECUTE format(
                'SELECT %I, %I, %I FROM fatores_compra_produto_servicos WHERE id = %L',
                'fator de emissão (kgCO2)',  -- Nome da coluna do fator de emissão
                'Unidade',
                'densidade',                    
                id_produto_input              -- ID do produto
            ) INTO fator_de_emissao_liquido, unidade_liquida, densidade;
        end if;

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
    quant_convertida := quant * fator_conv_un_medida;

    IF lower(un_input) = 'to' or lower(un_input) = 'tn' then
        un_input:= 't';
    end if;

    -- Ajustar para tonelada
    IF lower(un_input) = 'kg' AND lower(unidade_liquida) = 'kg' THEN
        -- Mesma unidade (kg), conversão no final
        emissao_total := quant_convertida * fator_emissao / 1000;

    ELSIF lower(un_input) = 't' AND lower(unidade_liquida) = 't' THEN
        -- Mesma unidade (tonelada), sem conversão extra
        emissao_total := quant_convertida * fator_emissao;

    ELSIF lower(un_input) = 't' AND lower(unidade_liquida) = 'kg' THEN
        -- Entrada em toneladas, fator em kg => converter fator
        emissao_total := quant_convertida * (fator_emissao / 1000);

    ELSIF lower(un_input) = 'kg' AND lower(unidade_liquida) = 't' THEN
        -- Entrada em kg, fator em toneladas => converter quantidade
        emissao_total := (quant_convertida / 1000) * fator_emissao;

    ELSE
        -- Outros casos ou unidade não tratada: aplicar normalmente
        emissao_total := quant_convertida * fator_emissao;
    END IF;

    -- Adiciona casos especiais de densidade para unidade líquida
    IF lower(unidade_liquida) = 'm3' THEN
        emissao_total := emissao_total / NULLIF(densidade, 0);
    END IF;

    emissao_total:=emissao_total/1000; --Dividir por 1000 ja que o fator de emissao é em kg
    erro_total := emissao_total * perc_erro;

    -- Retornar resultados
    RETURN QUERY SELECT fator_emissao, quant_convertida, emissao_total, erro_total;

END;
$$ LANGUAGE plpgsql;
