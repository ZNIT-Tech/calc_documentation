--drop function calcular_viagens_negocio_pernoite
CREATE OR REPLACE FUNCTION calcular_viagens_negocio_pernoite(
    number_of_nights NUMERIC,
    number_of_rooms NUMERIC
) RETURNS TABLE (
    fator_co2 NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    fator_co2 NUMERIC;
BEGIN

  fator_co2 := 8.7; --Defra 2024
  emissao_total := number_of_nights * number_of_rooms * fator_co2 / 1000;

  RETURN QUERY 
  SELECT fator_co2, emissao_total;

END;
$$ LANGUAGE plpgsql;
