--drop function calcular_combustao_movel_aereo
CREATE OR REPLACE FUNCTION calcular_combustao_movel_aereo(
    categoria_emissao_input TEXT,
    id_combustivel_input NUMERIC,
    consumo_anual_input NUMERIC,
    date_input DATE
) RETURNS TABLE (
    emissao_co2 NUMERIC,
    emissao_co2_biogenico NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    co2_fossil_factor NUMERIC,
    co2_bio_factor NUMERIC,
    ch4_fossil_factor NUMERIC,
    n2o_fossil_factor NUMERIC,
    ch4_bio_factor NUMERIC,
    n2o_bio_factor NUMERIC
) AS $$
DECLARE
    perc_etanol NUMERIC;
    perc_biodiesel NUMERIC;
    combustivel_fossil TEXT;
    combustivel_biocombustivel TEXT;
    co2_fossil_factor NUMERIC;
    co2_bio_factor NUMERIC;
    ch4_fossil_factor NUMERIC;
    n2o_fossil_factor NUMERIC;
    ch4_bio_factor NUMERIC;
    n2o_bio_factor NUMERIC;
    consumo_usado NUMERIC;
    mes_nome TEXT;
    ano_input INT;
BEGIN

  -- Obter fatores e combustíveis
  SELECT fossil, biocombustivel, co2_fossil, co2_bio, ch4_fossil, ch4_bio, n2o_fossil, n2o_bio
  INTO combustivel_fossil, combustivel_biocombustivel,
      co2_fossil_factor, co2_bio_factor,
      ch4_fossil_factor, ch4_bio_factor,
      n2o_fossil_factor, n2o_bio_factor
  FROM airtable_combustivel_emissao
  WHERE id = id_combustivel_input;

  emissao_co2 := co2_fossil_factor * consumo_anual_input / 1000;
  emissao_co2_biogenico := co2_bio_factor * consumo_anual_input / 1000;

  emissao_ch4 := 
    (ch4_fossil_factor * consumo_anual_input / 1000) + 
    (ch4_bio_factor * consumo_anual_input / 1000);

  emissao_n2o := 
    (n2o_fossil_factor * consumo_anual_input / 1000) + 
    (n2o_bio_factor * consumo_anual_input / 1000);

-- Calcular emissão total
  emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

  -- Retornar os resultados
  RETURN QUERY 
  SELECT emissao_co2, emissao_co2_biogenico,
          emissao_ch4, emissao_n2o, emissao_total,
          co2_fossil_factor, co2_bio_factor, ch4_fossil_factor, n2o_fossil_factor, ch4_bio_factor, n2o_bio_factor;

END;
$$ LANGUAGE plpgsql;
