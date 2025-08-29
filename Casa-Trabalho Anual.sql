--drop function calcular_emissoes_trabalho_casa
CREATE OR REPLACE FUNCTION calcular_emissoes_trabalho_casa_anual(
    categoria_emissao_input TEXT,
    tipo_veiculo_input NUMERIC,
    nro_passageiros_input NUMERIC,
    dist_percorrida_input NUMERIC,
    ano_input DATE,
    dias_trabalhados_semana INTEGER,
    meses_trabalhados INTEGER,
    ida_volta BOOLEAN
) RETURNS TABLE (
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    fator_co2 NUMERIC,
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    fator_co2_bio NUMERIC,
    fator_ch4_bio NUMERIC,
    fator_n2o_bio NUMERIC,
    perc_biodiesel NUMERIC,
    tipo_veiculo TEXT
) AS $$
DECLARE
    ano_extraido INT;
    fator_co2 NUMERIC;
    fator_ch4 NUMERIC;
    fator_n2o NUMERIC;
    fator_co2_bio NUMERIC;
    fator_ch4_bio NUMERIC;
    fator_n2o_bio NUMERIC;
    perc_biodiesel NUMERIC;
    emissao_co2_fossil NUMERIC;
    emissao_ch4_fossil NUMERIC;
    emissao_n2o_fossil NUMERIC;
    emissao_ch4_bio NUMERIC;
    emissao_n2o_bio NUMERIC;
    tipo_veiculo TEXT;
    dias_trabalhados_total NUMERIC;
BEGIN

    ano_extraido := EXTRACT(YEAR FROM ano_input)::INTEGER;

    -- Buscar percentual de biodiesel anual
    SELECT "Yearly"
    INTO perc_biodiesel
    FROM perc_de_etanol_biodiesel_e_de_do_sin
    WHERE "Parametros" = 'Perc. de Biodiesel no Diesel' 
    and CAST("Ano" AS INTEGER) = ano_extraido;

    SELECT "veiculo" INTO tipo_veiculo
    FROM lista_veiculos_viagens
    WHERE "id" = tipo_veiculo_input;

    -- Buscar fatores de emissão considerando o ano
    SELECT co2_fossil, ch4_fossil, n2o_fossil, co2_bio, ch4_bio, n2o_bio
    INTO fator_co2, fator_ch4, fator_n2o, fator_co2_bio, fator_ch4_bio, fator_n2o_bio
    FROM lista_veiculos_viagens
    WHERE veiculo = tipo_veiculo
    AND CAST(ano AS INTEGER) = ano_extraido;

    dias_trabalhados_total := meses_trabalhados * dias_trabalhados_semana * 4;

    -- Verificar se o tipo de veículo é Trem ou Metrô
    IF tipo_veiculo IN ('Trem', 'Metro') THEN
        -- Apenas CO₂ fóssil
        emissao_co2 := (nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total * fator_co2) / 1000000;
        emissao_ch4 := 0;
        emissao_n2o := 0;
        emissao_total := emissao_co2;

    -- Verificar se o tipo de veículo é Balsa
    ELSIF tipo_veiculo IN ('Balsa de passageiros', 'Balsa de veículos', 'Balsa híbrida veículos e passageiros') THEN
        -- Calcular emissões para Balsas
        emissao_co2 := (fator_co2 * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total) / 1000;
        emissao_ch4 := (fator_ch4 * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total) / 1000;
        emissao_n2o := (fator_n2o * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total) / 1000;

        -- Emissão total
        emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

    -- Verificar se o tipo de veículo é Ônibus
    ELSIF tipo_veiculo IN ('Ônibus municipal', 'Ônibus de viagem') THEN
        -- Calcular emissões fósseis
        emissao_co2_fossil := (fator_co2 * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total * (1 - perc_biodiesel)) / 1000;
        emissao_ch4_fossil := (fator_ch4 * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total * (1 - perc_biodiesel)) / 1000;
        emissao_n2o_fossil := (fator_n2o * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total * (1 - perc_biodiesel)) / 1000;

        -- Calcular emissões biocombustíveis
        emissao_ch4_bio := (fator_ch4_bio * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total * perc_biodiesel) / 1000;
        emissao_n2o_bio := (fator_n2o_bio * nro_passageiros_input * dist_percorrida_input * dias_trabalhados_total * perc_biodiesel) / 1000;

        -- Somar as emissões de CH₄ e N₂O (fóssil + biocombustível)
        emissao_co2 := emissao_co2_fossil;
        emissao_ch4 := emissao_ch4_fossil + emissao_ch4_bio;
        emissao_n2o := emissao_n2o_fossil + emissao_n2o_bio;

        -- Emissão total
        emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);
    else
        tipo_veiculo := tipo_veiculo;

    END IF;

    IF ida_volta then   
        emissao_total := emissao_total * 2;
        emissao_co2 := emissao_co2 * 2;
        emissao_ch4 := emissao_ch4 * 2;
        emissao_n2o := emissao_n2o * 2;
    END if;

    -- Retornar os valores calculados
    RETURN QUERY SELECT emissao_co2, emissao_ch4, emissao_n2o, emissao_total, fator_co2, fator_ch4, fator_n2o, fator_co2_bio, fator_ch4_bio, fator_n2o_bio, perc_biodiesel, tipo_veiculo;
END;
$$ LANGUAGE plpgsql;
