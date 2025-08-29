--drop function calcular_emissao_efluentes_mitre
CREATE OR REPLACE FUNCTION calcular_emissao_efluentes_mitre(
    quant_input NUMERIC,
    tecnologia TEXT
)
RETURNS TABLE (
    fator_ch4 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_total NUMERIC,
    erro_emissao_ch4 NUMERIC
) AS $$
DECLARE
    erro_ch4 NUMERIC;
BEGIN

    if tecnologia = 'Reator anaeróbico' then
        fator_ch4 := 0.024;
        erro_ch4 := 43.8748;
    else
        fator_ch4 := 0.0050411;
        erro_ch4 := 40.31;
    end if;

    -- Calcula as emissões
    emissao_ch4 := fator_ch4 * quant_input;

    emissao_total := emissao_ch4;

    -- Calcula os erros absolutos das emissões
    erro_emissao_ch4 := emissao_ch4 * (erro_ch4 / 100);

    -- Retorna os resultados
    RETURN QUERY SELECT
        fator_ch4,
        emissao_ch4,
        emissao_total,
        erro_emissao_ch4;
END;
$$ LANGUAGE plpgsql;
