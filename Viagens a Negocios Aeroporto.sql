CREATE OR REPLACE FUNCTION calcular_emissoes_aeroporto(
    id_aeroporto_saida INT,
    id_aeroporto_chegada INT
)
RETURNS TABLE (
    distancia_km NUMERIC,
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    lat1 NUMERIC;
    lon1 NUMERIC;
    lat2 NUMERIC;
    lon2 NUMERIC;
    fator_co2 NUMERIC;
    fator_ch4 NUMERIC;
    fator_n2o NUMERIC;
BEGIN
    -- Buscar coordenadas dos aeroportos de saída e chegada convertidas para formato decimal
    SELECT dms_to_decimal(latitude), dms_to_decimal(longitude)
    INTO lat1, lon1
    FROM lista_aeroportos
    WHERE id = id_aeroporto_saida;

    SELECT dms_to_decimal(latitude), dms_to_decimal(longitude)
    INTO lat2, lon2
    FROM lista_aeroportos
    WHERE id = id_aeroporto_chegada;

    -- Cálculo da distância (Haversine)
    distancia_km := 6371 * ACOS(
        COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
        COS(RADIANS(lon2) - RADIANS(lon1)) +
        SIN(RADIANS(lat1)) * SIN(RADIANS(lat2))
    );

    -- Determinar os fatores de emissão com base na distância
    IF distancia_km <= 500 THEN
        fator_co2 := 0.147611;
        fator_ch4 := 0.00000727513228;
        fator_n2o := 0.0000046820405;
    ELSIF distancia_km <= 3700 THEN
        fator_co2 := 0.10075;
        fator_ch4 := 0.00000033068783;
        fator_n2o := 0.0000032145353;
    ELSE
        fator_co2 := 0.141601851852;
        fator_ch4 := 0.00000033068783;
        fator_n2o := 0.0000045073375;
    END IF;

    -- Cálculo das emissões
    emissao_co2 := (distancia_km * fator_co2 * (1 + 0.08)) / 1000;
    emissao_ch4 := (distancia_km * fator_ch4 * (1 + 0.08)) / 1000;
    emissao_n2o := (distancia_km * fator_n2o * (1 + 0.08)) / 1000;

    -- Cálculo da emissão total
    emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

    -- Retornar os valores
    RETURN QUERY SELECT distancia_km, emissao_co2, emissao_ch4, emissao_n2o, emissao_total;
END;
$$ LANGUAGE plpgsql;
