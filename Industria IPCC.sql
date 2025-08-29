CREATE OR REPLACE FUNCTION calcular_emissoes_industrias_ipcc(
    chamine_1 NUMERIC,
    chamine_2 NUMERIC,
    chamine_3 NUMERIC,
    horas_trabalhadas NUMERIC,
    gwp_id INTEGER
) RETURNS TABLE (
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC
) AS $$
DECLARE
    soma NUMERIC := 0;
    contador NUMERIC := 0;
    media NUMERIC;
    gwp_valor NUMERIC;
BEGIN
    -- Buscar o valor do GWP correspondente na tabela lista_gwp
    SELECT gwp INTO gwp_valor FROM lista_gwp WHERE id = gwp_id;

    -- Se o ID do GWP não existir, definir como zero para evitar erro
    IF gwp_valor IS NULL THEN
        gwp_valor := 0;
    END IF;

    -- Somar apenas valores diferentes de zero e contar quantos são
    IF chamine_1 <> 0 THEN 
        soma := soma + chamine_1;
        contador := contador + 1;
    END IF;
    
    IF chamine_2 <> 0 THEN 
        soma := soma + chamine_2;
        contador := contador + 1;
    END IF;
    
    IF chamine_3 <> 0 THEN 
        soma := soma + chamine_3;
        contador := contador + 1;
    END IF;

    -- Evita divisão por zero
    IF contador > 0 THEN
        media := soma / contador;
    ELSE
        media := 0;
    END IF;

    -- Cálculo das emissões individuais
    emissao_co2 := 0;
    emissao_ch4 := 0;
    emissao_n2o := 0;

    -- Determinar a emissão total com base no GWP
    IF gwp_id = 1 THEN
        emissao_co2 := media * horas_trabalhadas / 1000;
        emissao_total := emissao_co2 * gwp_valor;
    ELSIF gwp_id = 2 THEN
        emissao_ch4 := media * horas_trabalhadas / 1000;
        emissao_total := emissao_ch4 * gwp_valor;
    ELSIF gwp_id = 3 THEN
        emissao_n2o := media * horas_trabalhadas / 1000;
        emissao_total := emissao_n2o * gwp_valor;
    ELSE
        emissao_total := 0;
    END IF;

    RETURN QUERY SELECT emissao_co2, emissao_ch4, emissao_n2o, emissao_total;
END;
$$ LANGUAGE plpgsql;
