--drop function calcular_emissoes_energia_eletrica
CREATE OR REPLACE FUNCTION calcular_emissoes_energia_eletrica(
    date_input DATE,
    consumo_mensal NUMERIC,
    consumo_anual NUMERIC,
    id_fonte_geracao_energia INT,
    id_combustivel_termoeletrico INT,
    fator_co2 NUMERIC,
    fator_ch4 NUMERIC,
    fator_n2o NUMERIC,
    fator_co2_bio NUMERIC,
    eficiencia_recuperacao NUMERIC,
    fator_personalizado BOOLEAN 
) RETURNS TABLE (
    fator_co2_utilizado NUMERIC,
    fator_ch4_utilizado NUMERIC,
    fator_n2o_utilizado NUMERIC,
    fator_co2_bio_utilizado NUMERIC,
    emissao_co2 NUMERIC,
    emissao_ch4 NUMERIC,
    emissao_n2o NUMERIC,
    emissao_total NUMERIC,
    emissao_biogenica NUMERIC,
    var_text TEXT
) AS $$
DECLARE
    consumo_utilizado NUMERIC;
    eficiencia_utilizada NUMERIC;
    termo_fator_co2 NUMERIC;
    termo_fator_ch4 NUMERIC;
    termo_fator_n2o NUMERIC;
    termo_fator_co2_bio NUMERIC;
    var_text TEXT;
BEGIN

    var_text := 'Vazio';
    -- Determinar os fatores de emissão com base na fonte de geração de energia
    IF id_fonte_geracao_energia = 6 THEN
        eficiencia_utilizada := COALESCE(eficiencia_recuperacao, 1); -- Se NULL, assume 1

        -- Se fator_personalizado = TRUE, usa os valores passados para a função
        -- Se fator_personalizado = FALSE, busca os valores da tabela
        IF fator_personalizado is true THEN
            fator_co2_utilizado := fator_co2;
            fator_ch4_utilizado := fator_ch4;
            fator_n2o_utilizado := fator_n2o;
            fator_co2_bio_utilizado := fator_co2_bio;

            var_text := 'Entrou1';

        ELSE
            -- Buscar os fatores da tabela fatores_emissao_energia_termo
            EXECUTE format(
                'SELECT tco2, tch4, tn2o, tco2 biogenico
                FROM fatores_emissao_energia_termo
                WHERE id = %L', id_combustivel_termoeletrico
            )
            INTO termo_fator_co2, termo_fator_ch4, termo_fator_n2o, termo_fator_co2_bio;

            fator_co2_utilizado := termo_fator_co2;
            fator_ch4_utilizado := termo_fator_ch4;
            fator_n2o_utilizado := termo_fator_n2o;
            fator_co2_bio_utilizado := termo_fator_co2_bio;

            var_text := 'Entrou2';

        END IF;
    ELSE
        eficiencia_utilizada := 1;
        fator_co2_utilizado := fator_co2;
        fator_ch4_utilizado := fator_ch4;
        fator_n2o_utilizado := fator_n2o;
        fator_co2_bio_utilizado := fator_co2_bio;

        var_text := 'Entrou3';

    END IF;

    -- Garantir que eficiencia_utilizada nunca seja 0 para evitar divisão por zero
    IF eficiencia_utilizada = 0 or eficiencia_utilizada is null THEN
        eficiencia_utilizada := 1;
    END IF;

    -- Determinar o consumo utilizado
    IF consumo_anual > 0 THEN
        consumo_utilizado := consumo_anual;
    ELSE
        consumo_utilizado := consumo_mensal;
    END IF;

    -- Calcular as emissões
    emissao_co2 := (consumo_utilizado / eficiencia_utilizada) * fator_co2_utilizado;
    emissao_ch4 := (consumo_utilizado / eficiencia_utilizada) * fator_ch4_utilizado;
    emissao_n2o := (consumo_utilizado / eficiencia_utilizada) * fator_n2o_utilizado;
    emissao_biogenica := (consumo_utilizado / eficiencia_utilizada) * fator_co2_bio_utilizado;

    -- Calcular emissões totais
    emissao_total := emissao_co2 + (emissao_ch4 * 28) + (emissao_n2o * 265);

    -- Retornar os valores calculados
    RETURN QUERY
    SELECT 
        fator_co2_utilizado,
        fator_ch4_utilizado,
        fator_n2o_utilizado,
        fator_co2_bio_utilizado,
        emissao_co2,
        emissao_ch4,
        emissao_n2o,
        emissao_total,
        emissao_biogenica,
        var_text;
END;
$$ LANGUAGE plpgsql;
