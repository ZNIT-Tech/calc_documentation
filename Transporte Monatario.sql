--drop function calcular_transporte_monetario
CREATE OR REPLACE FUNCTION calcular_transporte_monetario(
    transporte_input INTEGER,
    quant_input NUMERIC,
    un_input TEXT
)
RETURNS TABLE (
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    fator_co2 NUMERIC,
    fator_co2_bio NUMERIC,
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    emissao_bio NUMERIC,
    erro_emissao_co2 NUMERIC,
    erro_emissao_ch4 NUMERIC,
    erro_emissao_n2o NUMERIC,
    erro_emissao_bio NUMERIC
) AS $$
DECLARE
    unidade_fator TEXT;
    erro_co2 NUMERIC;
    erro_n2o NUMERIC;
    erro_ch4 NUMERIC;
    erro_co2_bio NUMERIC;
BEGIN

    -- Busca os fatores e os erros
    SELECT p."CO2_renovavel", p."N2O", p."CO2", p."CH4", p.unidade,
           p.erro_co2_renovavel, p.erro_n2o, p.erro_co2, p.erro_ch4
    INTO fator_co2_bio, fator_n2o, fator_co2, fator_ch4, unidade_fator,
         erro_co2_bio, erro_n2o, erro_co2, erro_ch4
    FROM fatores_monetario_veiculos p
    WHERE p.id = transporte_input;

    -- Calcula as emissões
    emissao_co2 := fator_co2 * quant_input;
    emissao_ch4 := fator_ch4 * quant_input;
    emissao_n2o := fator_n2o * quant_input;
    emissao_bio := fator_co2_bio * quant_input;

    IF un_input = 'R$' or un_input = 'r$' THEN
        emissao_co2 := emissao_co2 / 1000;
        emissao_ch4 := emissao_ch4 / 1000;
        emissao_n2o := emissao_n2o / 1000;
        emissao_bio := emissao_bio / 1000;
    END IF;

    emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

    -- Calcula os erros absolutos das emissões
    erro_emissao_co2 := emissao_co2 * (erro_co2 / 100);
    erro_emissao_ch4 := emissao_ch4 * (erro_ch4 / 100);
    erro_emissao_n2o := emissao_n2o * (erro_n2o / 100);
    erro_emissao_bio := emissao_bio * (erro_co2_bio / 100);

    -- Retorna os resultados
    RETURN QUERY SELECT
        fator_ch4,
        fator_n2o,
        fator_co2,
        fator_co2_bio,
        emissao_co2,
        emissao_ch4,
        emissao_n2o,
        emissao_total,
        emissao_bio,
        erro_emissao_co2,
        erro_emissao_ch4,
        erro_emissao_n2o,
        erro_emissao_bio;
END;
$$ LANGUAGE plpgsql;
