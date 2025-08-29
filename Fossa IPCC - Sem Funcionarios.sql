CREATE OR REPLACE FUNCTION calcular_emissoes_fossa_ipcc_sem_funcionarios(
    mfc NUMERIC,
    dbo_forte NUMERIC,
    maximo_ch4 NUMERIC,
    volume_anual NUMERIC
) RETURNS TABLE (
    emissao_total NUMERIC,
    fator_emissao NUMERIC,
    emissao_ch4 NUMERIC
) AS $$
DECLARE
    emissao_total NUMERIC;
    fator_emissao NUMERIC;
    emissao_ch4 NUMERIC;
BEGIN

    IF mfc IS NULL THEN
        mfc := 0.5;
    END IF;

    IF maximo_ch4 IS NULL THEN
        maximo_ch4 := 0.6;
    END IF;

    fator_emissao := mfc * maximo_ch4 * dbo_forte;
    emissao_ch4 := fator_emissao * volume_anual / 1000;
    emissao_total := emissao_ch4 * 28;

    -- Retorna a variável emissao_total
    RETURN QUERY SELECT emissao_total, fator_emissao, emissao_ch4;
END;
$$ LANGUAGE plpgsql;
