CREATE OR REPLACE FUNCTION calcular_emissoes_agricolas_ipcc(
    quant NUMERIC,
    percent_n NUMERIC,
    fator_n2o NUMERIC,
    fator_co2 NUMERIC
) RETURNS TABLE (
    emissao_total NUMERIC,
    emissao_co2 NUMERIC,
    emissao_n2o NUMERIC
) AS $$
DECLARE
    emissao_total NUMERIC;
    emissao_co2 NUMERIC;
    emissao_n2o NUMERIC;
BEGIN
    emissao_n2o := 0;
    emissao_co2 := 0;
    emissao_n2o := (quant * (percent_n/100) * fator_n2o) /1000;
    emissao_co2 := (quant * fator_co2) / 1000;
    emissao_total := emissao_co2 + (emissao_n2o * 265);

    RETURN QUERY SELECT emissao_total, emissao_co2, emissao_n2o;
END;
$$ LANGUAGE plpgsql;
