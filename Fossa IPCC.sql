--drop function calcular_emissoes_fossa_ipcc
CREATE OR REPLACE FUNCTION calcular_emissoes_fossa_ipcc(
    mfc NUMERIC,
    dbo_forte NUMERIC,
    ch4_recuperado NUMERIC,
    horas_trabalhadas NUMERIC,
    dias_trabalhados NUMERIC,
    meses_trabalhados NUMERIC,
    fator_correcao_do_fator_emissao NUMERIC,
    quant_colaboradores NUMERIC
) RETURNS TABLE (
    emissao_total NUMERIC,
    fator_colaborador NUMERIC,
    emissao_ch4 NUMERIC
) AS $$
DECLARE
    emissao_total NUMERIC;
    fator_colaborador NUMERIC;
    emissao_ch4 NUMERIC;
BEGIN
    -- Garante que os valores NULL são substituídos pelos padrões
    mfc := COALESCE(mfc, 0.5);
    dbo_forte := COALESCE(dbo_forte, 0.4);
    ch4_recuperado := COALESCE(ch4_recuperado, 0.6);
    horas_trabalhadas := COALESCE(horas_trabalhadas, 0.018);
    dias_trabalhados := COALESCE(dias_trabalhados, 21);
    meses_trabalhados := COALESCE(meses_trabalhados, 12);
    fator_correcao_do_fator_emissao := COALESCE(fator_correcao_do_fator_emissao, 1.25);

    -- Cálculo do fator colaborador
    fator_colaborador := mfc  
                      * ch4_recuperado 
                      * horas_trabalhadas 
                      * dias_trabalhados 
                      * meses_trabalhados 
                      * fator_correcao_do_fator_emissao;

    -- Cálculo da emissão total
    emissao_ch4 := fator_colaborador * quant_colaboradores / 1000;
    emissao_total := fator_colaborador * quant_colaboradores * 28 / 1000;

    -- Retorna os valores
    RETURN QUERY SELECT emissao_total, fator_colaborador, emissao_ch4;
END;
$$ LANGUAGE plpgsql;
