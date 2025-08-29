--DROP FUNCTION calcular_residuos_solidos_3
CREATE OR REPLACE FUNCTION calcular_residuos_solidos_3_new(
    categoria_emissao_input TEXT,
    id_uf_input INT,
    data_input DATE,
    cnpj_usuario_input TEXT,
    composicao_papelao FLOAT,
    composicao_textil FLOAT,
    composicao_alimentar FLOAT,
    composicao_madeira FLOAT,
    composicao_jardim FLOAT,
    composicao_fraldas FLOAT,
    composicao_borracha FLOAT,
    composicao_lodo_domestico FLOAT,
    composicao_lodo_industrial FLOAT,
    classificacao_ano TEXT,
    fracao_ch4_biogas FLOAT,
    recuperacao_metano TEXT,
    eficiencia_recuperacao FLOAT
) RETURNS TABLE (
    temp_media NUMERIC,
    pluviosidade_anual NUMERIC,
    potencial_evapotransp NUMERIC,
    uf TEXT,
    residuos_aterro NUMERIC,
    mcf NUMERIC,
    ox NUMERIC,
    f_adimensional NUMERIC,
    fator_recuperacao NUMERIC,
    k_papel NUMERIC,
    k_textil NUMERIC,
    k_alimentar NUMERIC,
    k_madeira NUMERIC,
    k_jardim NUMERIC,
    k_fraldas NUMERIC,
    k_borracha NUMERIC,
    k_lodo_domestico NUMERIC,
    k_lodo_industrial NUMERIC,
    emissao_ch4_ano NUMERIC[],
    emissao_co2e_ano NUMERIC[],
    doc_bu_papel NUMERIC,
    doc_bu_textil NUMERIC,
    doc_bu_alimentar NUMERIC,
    doc_bu_madeira NUMERIC,
    doc_bu_jardim NUMERIC ,
    doc_bu_fraldas NUMERIC ,
    doc_bu_borracha NUMERIC,
    doc_bu_lodo_domestico NUMERIC ,
    doc_bu_lodo_industrial NUMERIC ,
    docf_mod NUMERIC ,
    docf_high NUMERIC ,
    docf_less NUMERIC ,
    doc_depositado_papel NUMERIC,
    doc_depositado_textil NUMERIC,
    doc_depositado_alimentar NUMERIC,
    doc_depositado_madeira NUMERIC,
    doc_depositado_jardim NUMERIC,
    doc_depositado_fraldas NUMERIC,
    doc_depositado_borracha NUMERIC,
    doc_depositado_lodo_domestico NUMERIC,
    doc_depositado_lodo_industrial NUMERIC,
    doc_acumulado_papel NUMERIC[],
    doc_acumulado_textil NUMERIC[],
    doc_acumulado_alimentar NUMERIC[],
    doc_acumulado_madeira NUMERIC[],
    doc_acumulado_jardim NUMERIC[],
    doc_acumulado_fraldas NUMERIC[],
    doc_acumulado_borracha NUMERIC[],
    doc_acumulado_lodo_domestico NUMERIC[],
    doc_acumulado_lodo_industrial NUMERIC[],
    doc_decomposto_papel NUMERIC[],
    doc_decomposto_textil NUMERIC[],
    doc_decomposto_alimentar NUMERIC[],
    doc_decomposto_madeira NUMERIC[],
    doc_decomposto_jardim NUMERIC[],
    doc_decomposto_fraldas NUMERIC[],
    doc_decomposto_borracha NUMERIC[],
    doc_decomposto_lodo_domestico NUMERIC[],
    doc_decomposto_lodo_industrial NUMERIC[],
    metano_gerado_ano NUMERIC[],
    ch4_total NUMERIC,
    co2_total NUMERIC
) AS $$
DECLARE
    var_temp_media NUMERIC;
    var_pluviosidade_anual NUMERIC;
    var_potencial_evapotransp NUMERIC;
    var_uf TEXT;
    residuos_aterro NUMERIC;
    mcf NUMERIC;
    ox NUMERIC;
    f_adimensional NUMERIC;
    fator_recuperacao NUMERIC;
    k_papel NUMERIC;
    k_textil NUMERIC;
    k_alimentar NUMERIC;
    k_madeira NUMERIC;
    k_jardim NUMERIC;
    k_fraldas NUMERIC;
    k_borracha NUMERIC;
    k_lodo_domestico NUMERIC;
    k_lodo_industrial NUMERIC;
    doc_bu_papel NUMERIC := 0.4;
    doc_bu_textil NUMERIC := 0.24;
    doc_bu_alimentar NUMERIC := 0.15;
    doc_bu_madeira NUMERIC := 0.43;
    doc_bu_jardim NUMERIC := 0.20;
    doc_bu_fraldas NUMERIC := 0.24;
    doc_bu_borracha NUMERIC := 0.39;
    doc_bu_lodo_domestico NUMERIC := 0.05;
    doc_bu_lodo_industrial NUMERIC := 0.09;
    docf_mod NUMERIC := 0.5;
    docf_high NUMERIC := 0.7;
    docf_less NUMERIC := 0.1;
    doc_acumulado NUMERIC[] := ARRAY[]::NUMERIC[];
    doc_decomposto NUMERIC[] := ARRAY[]::NUMERIC[];
    metano_gerado NUMERIC[] := ARRAY[]::NUMERIC[];
    emissao_ch4 NUMERIC[] := ARRAY[]::NUMERIC[];
    emissao_co2e NUMERIC[] := ARRAY[]::NUMERIC[];
    ch4_total_calc NUMERIC := 0;
    co2_total_calc NUMERIC := 0;
BEGIN
    -- Selecionar os valores associados ao id_uf_input
    SELECT lm.temp_media, lm.pluviosidade_anual, lm.potencial_evapotransp, lm.municipios_br AS uf
    INTO var_temp_media, var_pluviosidade_anual, var_potencial_evapotransp, var_uf
    FROM lista_pluviosidade_municipios lm
    WHERE lm.id = id_uf_input;

    -- Calcular a soma dos resíduos para o ano da data fornecida e o CNPJ do usuário
    SELECT SUM(r.residuos_aterro)
    INTO residuos_aterro
    FROM "Main_DataNew" r
    WHERE r.cnpj_usuario = cnpj_usuario_input
      AND DATE_PART('year', r.date) = DATE_PART('year', data_input)
      AND r.categoria_de_emissoes = 'RESIDUOS SOLIDOS DA OPERACAO';

    IF residuos_aterro IS NULL THEN
        residuos_aterro := 0;
    END IF;
    
    -- Cálculo de MCF
    mcf := CASE classificacao_ano
               WHEN 'A' THEN 1.0
               WHEN 'B' THEN 0.5
               WHEN 'C' THEN 0.7
               WHEN 'D' THEN 0.4
               WHEN 'E' THEN 0.7
               WHEN 'F' THEN 0.8
               WHEN 'G' THEN 0.4
               WHEN 'H' THEN 0.6
               ELSE 0
           END;

    -- Cálculo de OX
    ox := CASE WHEN mcf >= 0.8 THEN 0.1 ELSE 0 END;

    -- Cálculo de f_adimensional
    f_adimensional := CASE WHEN fracao_ch4_biogas = 0 THEN 0.5 ELSE fracao_ch4_biogas END;

    -- Cálculo de fator de recuperação
    fator_recuperacao := 
    CASE 
        WHEN recuperacao_metano = 'sim' THEN 
            CASE 
                WHEN eficiencia_recuperacao = 0 THEN 0.2
                ELSE eficiencia_recuperacao
            END
        WHEN recuperacao_metano = 'nao' THEN 0
        ELSE 0.093
    END;

    -- Calcular valores de k com base na condição de temperatura e pluviosidade
    k_papel := CASE 
                   WHEN var_temp_media > 20 THEN
                       CASE 
                           WHEN var_pluviosidade_anual < 1000 THEN 0.045
                           ELSE 0.07
                       END
                   ELSE
                       CASE
                           WHEN var_pluviosidade_anual / var_potencial_evapotransp < 1 THEN 0.04
                           ELSE 0.06
                       END
               END;

    k_textil := k_papel;
    k_alimentar := CASE 
                       WHEN var_temp_media > 20 THEN
                           CASE 
                               WHEN var_pluviosidade_anual < 1000 THEN 0.085
                               ELSE 0.4
                           END
                       ELSE
                           CASE
                               WHEN var_pluviosidade_anual / var_potencial_evapotransp < 1 THEN 0.06
                               ELSE 0.185
                           END
                   END;

    k_madeira := CASE 
                       WHEN var_temp_media > 20 THEN
                           CASE 
                               WHEN var_pluviosidade_anual < 1000 THEN 0.025
                               ELSE 0.035
                           END
                       ELSE
                           CASE
                               WHEN var_pluviosidade_anual / var_potencial_evapotransp < 1 THEN 0.02
                               ELSE 0.03
                           END
                   END;               

    k_jardim := CASE 
                       WHEN var_temp_media > 20 THEN
                           CASE 
                               WHEN var_pluviosidade_anual < 1000 THEN 0.065
                               ELSE 0.17
                           END
                       ELSE
                           CASE
                               WHEN var_pluviosidade_anual / var_potencial_evapotransp < 1 THEN 0.05
                               ELSE 0.1
                           END
                   END;     

    k_fraldas := k_jardim;
    k_borracha := k_jardim;
    k_lodo_domestico := k_alimentar;
    k_lodo_industrial := k_alimentar;

    -- Calcular DOC depositado por categoria
    doc_depositado_papel := doc_bu_papel * residuos_aterro * composicao_papelao * mcf * docf_mod;
    doc_depositado_textil := doc_bu_textil * residuos_aterro * composicao_textil * mcf * docf_mod;
    doc_depositado_alimentar := doc_bu_alimentar * residuos_aterro * composicao_alimentar * mcf * docf_high;
    doc_depositado_madeira := doc_bu_madeira * residuos_aterro * composicao_madeira * mcf * docf_less;
    doc_depositado_jardim := doc_bu_jardim * residuos_aterro * composicao_jardim * mcf * docf_high;
    doc_depositado_fraldas := doc_bu_fraldas * residuos_aterro * composicao_fraldas * mcf * docf_mod;
    doc_depositado_borracha := doc_bu_borracha * residuos_aterro * composicao_borracha * mcf * docf_mod;
    doc_depositado_lodo_domestico := doc_bu_lodo_domestico * residuos_aterro * composicao_lodo_domestico * mcf * docf_high;
    doc_depositado_lodo_industrial := doc_bu_lodo_industrial * residuos_aterro * composicao_lodo_industrial * mcf * docf_high;

    IF doc_depositado_papel IS NULL THEN
        doc_depositado_papel := 0;
    END IF;

    IF doc_depositado_textil IS NULL THEN
        doc_depositado_textil := 0;
    END IF;

    IF doc_depositado_alimentar IS NULL THEN
        doc_depositado_alimentar := 0;
    END IF;

    IF doc_depositado_madeira IS NULL THEN
        doc_depositado_madeira := 0;
    END IF;

    IF doc_depositado_jardim IS NULL THEN
        doc_depositado_jardim := 0;
    END IF;

    IF doc_depositado_fraldas IS NULL THEN
        doc_depositado_fraldas := 0;
    END IF;

    IF doc_depositado_borracha IS NULL THEN
        doc_depositado_borracha := 0;
    END IF;

    IF doc_depositado_lodo_domestico IS NULL THEN
        doc_depositado_lodo_domestico := 0;
    END IF;

    IF doc_depositado_lodo_industrial IS NULL THEN
        doc_depositado_lodo_industrial := 0;
    END IF;

    doc_acumulado_papel := ARRAY[doc_depositado_papel];
    doc_acumulado_textil := ARRAY[doc_depositado_textil];
    doc_acumulado_alimentar := ARRAY[doc_depositado_alimentar];
    doc_acumulado_madeira := ARRAY[doc_depositado_madeira];
    doc_acumulado_jardim := ARRAY[doc_depositado_jardim];
    doc_acumulado_fraldas := ARRAY[doc_depositado_fraldas];
    doc_acumulado_borracha := ARRAY[doc_depositado_borracha];
    doc_acumulado_lodo_domestico := ARRAY[doc_depositado_lodo_domestico];
    doc_acumulado_lodo_industrial := ARRAY[doc_depositado_lodo_industrial];

    doc_decomposto_papel := ARRAY[0];
    doc_decomposto_textil := ARRAY[0];
    doc_decomposto_alimentar := ARRAY[0];
    doc_decomposto_madeira := ARRAY[0];
    doc_decomposto_jardim := ARRAY[0];
    doc_decomposto_fraldas := ARRAY[0];
    doc_decomposto_borracha := ARRAY[0];
    doc_decomposto_lodo_domestico := ARRAY[0];
    doc_decomposto_lodo_industrial := ARRAY[0];

    emissao_ch4_ano := ARRAY[]::NUMERIC[];
    metano_gerado := ARRAY[]::NUMERIC[];

    FOR i IN 1..29 LOOP
        doc_acumulado_papel := doc_acumulado_papel || (doc_acumulado_papel[i] * EXP(-k_papel));
        doc_acumulado_textil := doc_acumulado_textil || (doc_acumulado_textil[i] * EXP(-k_textil));
        doc_acumulado_alimentar := doc_acumulado_alimentar || (doc_acumulado_alimentar[i] * EXP(-k_alimentar));
        doc_acumulado_madeira := doc_acumulado_madeira || (doc_acumulado_madeira[i] * EXP(-k_madeira));
        doc_acumulado_jardim := doc_acumulado_jardim || (doc_acumulado_jardim[i] * EXP(-k_jardim));
        doc_acumulado_fraldas := doc_acumulado_fraldas || (doc_acumulado_fraldas[i] * EXP(-k_fraldas));
        doc_acumulado_borracha := doc_acumulado_borracha || (doc_acumulado_borracha[i] * EXP(-k_borracha));
        doc_acumulado_lodo_domestico := doc_acumulado_lodo_domestico || (doc_acumulado_lodo_domestico[i] * EXP(-k_lodo_domestico));
        doc_acumulado_lodo_industrial := doc_acumulado_lodo_industrial || (doc_acumulado_lodo_industrial[i] * EXP(-k_lodo_industrial));

        doc_decomposto_papel := doc_decomposto_papel || (doc_acumulado_papel[i] * (1 - EXP(-k_papel)));
        doc_decomposto_textil := doc_decomposto_textil || (doc_acumulado_textil[i] * (1 - EXP(-k_textil)));
        doc_decomposto_alimentar := doc_decomposto_alimentar || (doc_acumulado_alimentar[i] * (1 - EXP(-k_alimentar)));
        doc_decomposto_madeira := doc_decomposto_madeira || (doc_acumulado_madeira[i] * (1 - EXP(-k_madeira)));
        doc_decomposto_jardim := doc_decomposto_jardim || (doc_acumulado_jardim[i] * (1 - EXP(-k_jardim)));
        doc_decomposto_fraldas := doc_decomposto_fraldas || (doc_acumulado_fraldas[i] * (1 - EXP(-k_fraldas)));
        doc_decomposto_borracha := doc_decomposto_borracha || (doc_acumulado_borracha[i] * (1 - EXP(-k_borracha)));
        doc_decomposto_lodo_domestico := doc_decomposto_lodo_domestico || (doc_acumulado_lodo_domestico[i] * (1 - EXP(-k_lodo_domestico)));
        doc_decomposto_lodo_industrial := doc_decomposto_lodo_industrial || (doc_acumulado_lodo_industrial[i] * (1 - EXP(-k_lodo_industrial)));

    END LOOP;
    
    FOR i IN 1..ARRAY_LENGTH(doc_decomposto_papel, 1) LOOP
        IF doc_decomposto_papel[i] IS NULL THEN
            doc_decomposto_papel[i] := 0;
        END IF;
        IF doc_decomposto_textil[i] IS NULL THEN
            doc_decomposto_textil[i] := 0;
        END IF;
        IF doc_decomposto_alimentar[i] IS NULL THEN
            doc_decomposto_alimentar[i] := 0;
        END IF;
        IF doc_decomposto_madeira[i] IS NULL THEN
            doc_decomposto_madeira[i] := 0;
        END IF;
        IF doc_decomposto_jardim[i] IS NULL THEN
            doc_decomposto_jardim[i] := 0;
        END IF;
        IF doc_decomposto_fraldas[i] IS NULL THEN
            doc_decomposto_fraldas[i] := 0;
        END IF;
        IF doc_decomposto_borracha[i] IS NULL THEN
            doc_decomposto_borracha[i] := 0;
        END IF;
        IF doc_decomposto_lodo_domestico[i] IS NULL THEN
            doc_decomposto_lodo_domestico[i] := 0;
        END IF;
        IF doc_decomposto_lodo_industrial[i] IS NULL THEN
            doc_decomposto_lodo_industrial[i] := 0;
        END IF;
    END LOOP;

    ch4_total := 0;
    co2_total := 0;

    FOR j IN 0..30 LOOP
        IF j > 0 THEN
            metano_gerado := metano_gerado || (
                (doc_decomposto_papel[j] +
                doc_decomposto_textil[j] +
                doc_decomposto_alimentar[j] +
                doc_decomposto_madeira[j] +
                doc_decomposto_jardim[j] +
                doc_decomposto_fraldas[j] +
                doc_decomposto_borracha[j] +
                doc_decomposto_lodo_domestico[j] +
                doc_decomposto_lodo_industrial[j]) * 1.333333333333333333333 * f_adimensional
            );
            emissao_ch4_ano := array_append(emissao_ch4_ano, 
                (1 - fator_recuperacao) * metano_gerado[j] * (1 - ox)
            );

            -- Calcular emissões de CO₂e para cada ano
            emissao_co2e_ano := array_append(emissao_co2e_ano, 
                emissao_ch4_ano[j] * 28
            );

        END IF;
    END LOOP;

    SELECT SUM(value) INTO ch4_total
    FROM unnest(emissao_ch4_ano) AS value;

    SELECT SUM(value) INTO co2_total
    FROM unnest(emissao_co2e_ano) AS value;


    RETURN QUERY SELECT
        var_temp_media,
        var_pluviosidade_anual,
        var_potencial_evapotransp,
        var_uf,
        residuos_aterro,
        mcf,
        ox,
        f_adimensional,
        fator_recuperacao,
        k_papel,
    	k_textil,
    	k_alimentar,
    	k_madeira,
    	k_jardim,
    	k_fraldas,
   	    k_borracha,
   	    k_lodo_domestico,
    	k_lodo_industrial,
        emissao_ch4_ano,
        emissao_co2e_ano,
        doc_bu_papel,
        doc_bu_textil,
        doc_bu_alimentar,
        doc_bu_madeira,
        doc_bu_jardim,
        doc_bu_fraldas,
        doc_bu_borracha,
        doc_bu_lodo_domestico,
        doc_bu_lodo_industrial,
        docf_mod,
        docf_high,
        docf_less,
        doc_depositado_papel,
        doc_depositado_textil,
        doc_depositado_alimentar,
        doc_depositado_madeira,
        doc_depositado_jardim,
        doc_depositado_fraldas,
        doc_depositado_borracha,
        doc_depositado_lodo_domestico,
        doc_depositado_lodo_industrial,
        doc_acumulado_papel,
        doc_acumulado_textil,
        doc_acumulado_alimentar,
        doc_acumulado_madeira,
        doc_acumulado_jardim,
        doc_acumulado_fraldas,
        doc_acumulado_borracha,
        doc_acumulado_lodo_domestico,
        doc_acumulado_lodo_industrial,
        doc_decomposto_papel,
        doc_decomposto_textil,
        doc_decomposto_alimentar,
        doc_decomposto_madeira,
        doc_decomposto_jardim,
        doc_decomposto_fraldas,
        doc_decomposto_borracha,
        doc_decomposto_lodo_domestico,
        doc_decomposto_lodo_industrial,
        metano_gerado,
        ch4_total,
        co2_total;
END;
$$ LANGUAGE plpgsql;
