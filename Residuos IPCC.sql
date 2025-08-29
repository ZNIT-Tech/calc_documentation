--drop function calcular_emissoes_residuos_ipcc
CREATE OR REPLACE FUNCTION calcular_emissoes_residuos_ipcc(
  consumo_mensal NUMERIC,
  destino_residuo_ipcc NUMERIC,
  residuo_ipcc NUMERIC,
  un TEXT,
  cnpj_usuario TEXT,
  tecnologia TEXT
) RETURNS TABLE (
  emissao_co2_total NUMERIC,
  emissao_ch4_total NUMERIC,
  emissao_n2o_total NUMERIC,
  fator_co2 NUMERIC,
  fator_ch4 NUMERIC,
  fator_n2o NUMERIC,
  emissao_total NUMERIC,
  emissao_co2_bio NUMERIC
) AS $$
DECLARE
  emissao_co2_bio NUMERIC;
  emissao_total NUMERIC;
  destino_nome TEXT;
  fator_co2 NUMERIC;
  fator_ch4 NUMERIC;
  fator_n2o NUMERIC;
  fator_co2_bio NUMERIC;
  consumo_convertido NUMERIC;
BEGIN
  -- Converter kg para toneladas se necessário
  IF un ILIKE 'kg' THEN
    consumo_convertido := consumo_mensal / 1000;
  ELSE
    consumo_convertido := consumo_mensal;
  END IF;

  IF cnpj_usuario = '07882930000165' then
    IF tecnologia in('Sitio de disposicao de residuos solidos / Manejado / Anaerobico', 'Sítio de disposição de resíduos sólidos / Manejado / Anaeróbico')  and un ILIKE 't' THEN --Residuos solidos urbanos
      fator_co2:= 0.00179483;
      fator_ch4:= 0.053661;
      fator_n2o:= 0;
      fator_co2_bio:= 0.178566;

    ELSIF tecnologia in('Sitio de disposicao de residuos solidos / Manejado / Anaerobico', 'Sítio de disposição de resíduos sólidos / Manejado / Anaeróbico')  and un ILIKE 'm3' THEN --Residuos industriais
      fator_co2:= 0.00996233;
      fator_ch4:= 0.01482;
      fator_n2o:= 0;
      fator_co2_bio:= 0.0398493;

    ELSIF tecnologia = 'Compostagem' then
      fator_co2:= 0;
      fator_ch4:= 0.004;
      fator_n2o:= 0.00024;
      fator_co2_bio:= 0;

    ELSIF tecnologia = 'Coprocessamento' then
      fator_co2:= 0.291383;
      fator_ch4:= 0.000402907;
      fator_n2o:= 0.0000537209;
      fator_co2_bio:= 0.762627;

    ELSE
      fator_co2:= 0;
      fator_ch4:= 0;
      fator_n2o:= 0;
      fator_co2_bio:= 0;
    END if;

    emissao_co2_total := consumo_convertido * fator_co2;
    emissao_ch4_total := consumo_convertido * fator_ch4;
    emissao_n2o_total := consumo_convertido * fator_n2o;
    emissao_co2_bio := consumo_convertido * fator_co2_bio;
    emissao_total := emissao_co2_total + (emissao_ch4_total * 28) + (emissao_n2o_total * 265);

    RETURN QUERY SELECT emissao_co2_total, emissao_ch4_total, emissao_n2o_total, fator_co2, fator_ch4, fator_n2o, emissao_total, emissao_co2_bio;
    RETURN;
  ELSE
    -- Obter o nome do destino do resíduo
    SELECT destino INTO destino_nome
    FROM lista_destino_residuos_ipcc
    WHERE id = destino_residuo_ipcc;

    -- Obter o fator de emissão para CO₂
    EXECUTE format(
      'SELECT %I FROM lista_fatores_emissao_residuos_ipcc_co2 WHERE id = %s',
      destino_nome, residuo_ipcc
    ) INTO fator_co2;

    -- Obter o fator de emissão para CH₄
    EXECUTE format(
      'SELECT %I FROM lista_fatores_emissao_residuos_ipcc_ch4 WHERE id = %s',
      destino_nome, residuo_ipcc
    ) INTO fator_ch4;

    -- Obter o fator de emissão para N₂O
    EXECUTE format(
      'SELECT %I FROM lista_fatores_emissao_residuos_ipcc_n2o WHERE id = %s',
      destino_nome, residuo_ipcc
    ) INTO fator_n2o;

    fator_co2_bio := 0;
  END IF;
    -- Calcular as emissões totais
  emissao_co2_total := consumo_convertido * fator_co2;
  emissao_ch4_total := consumo_convertido * fator_ch4;
  emissao_n2o_total := consumo_convertido * fator_n2o;
  emissao_co2_bio := consumo_convertido * fator_co2_bio;
  emissao_total := emissao_co2_total + (emissao_ch4_total * 28) + (emissao_n2o_total * 265);

  RETURN QUERY SELECT emissao_co2_total, emissao_ch4_total, emissao_n2o_total, fator_co2, fator_ch4, fator_n2o, emissao_total, emissao_co2_bio;
END;
$$ LANGUAGE plpgsql;
