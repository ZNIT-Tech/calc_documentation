--drop function calcular_emissao_uso_solo
CREATE OR REPLACE FUNCTION public.calcular_emissao_uso_solo(
    id_estado INT,
    id_uso_anterior_solo INT,
    id_uso_posterior_solo INT,
    id_bioma_anterior INT,
    area_mus NUMERIC,
    tipo_vegetacao_anterior TEXT,
    fitonomia_anterior BOOLEAN,
    id_bioma_posterior INT,
    dados_primarios_estoque_carbono BOOLEAN,
    estoque_carbono_solo NUMERIC,
    estoque_carbono_biomassa NUMERIC,
    detalhamento_vegetacao TEXT,
    fator_personalizado BOOLEAN
)
RETURNS TABLE(
    soc_ref NUMERIC,
    FLU_anterior NUMERIC, 
    FMG_anterior NUMERIC,
    FI_anterior NUMERIC,
    carbono_solo_anterior NUMERIC,
    carbono_biomassa_anterior NUMERIC,
    FLU_posterior NUMERIC,
    FMG_posterior NUMERIC,
    FI_posterior NUMERIC,
    carbono_solo_posterior NUMERIC,
    carbono_biomassa_posterior NUMERIC,
    emissao_absoluta_solo NUMERIC, 
    remocao_absoluta_solo NUMERIC, 
    periodo_amortizacao_solo INT, 
    emissao_reportar_solo NUMERIC, 
    remocao_amortizada_solo NUMERIC, 
    emissao_absoluta_biomassa NUMERIC, 
    remocao_absoluta_biomassa NUMERIC, 
    emissao_reportar_biomassa NUMERIC, 
    remocao_reportar_biomassa NUMERIC, 
    remocao_reportar_amortizada_biomassa NUMERIC, 
    emissao_amortizada_total NUMERIC, 
    remocao_amortizada_total NUMERIC, 
    emissao_total_co2 NUMERIC,
    emissao_total_biogenico NUMERIC
) AS $$
DECLARE
    sigla_estado TEXT;
    soc_ref NUMERIC;
    
    uso_anterior_nome TEXT;
    uso_posterior_nome TEXT;

    tipo_bioma_anterior TEXT;
    tipo_bioma_posterior TEXT;

    FLU_anterior NUMERIC := 0;
    FMG_anterior NUMERIC := 0;
    FI_anterior NUMERIC := 0;
    carbono_solo_anterior NUMERIC := 0;
    carbono_biomassa_anterior NUMERIC := 0;
    estoque_total_anterior NUMERIC := 0;

    FLU_posterior NUMERIC := 0;
    FMG_posterior NUMERIC := 0;
    FI_posterior NUMERIC := 0;
    carbono_solo_posterior NUMERIC := 0;
    carbono_biomassa_posterior NUMERIC := 0;
    estoque_total_posterior NUMERIC := 0;

    emissao_absoluta_solo NUMERIC := 0;
    remocao_absoluta_solo NUMERIC := 0;
    periodo_amortizacao_solo INT := 0;
    emissao_reportar_solo NUMERIC := 0;
    remocao_amortizada_solo NUMERIC := 0;

    emissao_absoluta_biomassa NUMERIC := 0;
    remocao_absoluta_biomassa NUMERIC := 0;
    periodo_amortizacao_biomassa INT := 0;
    emissao_reportar_biomassa NUMERIC := 0;
    remocao_reportar_biomassa NUMERIC := 0;
    remocao_reportar_amortizada_biomassa NUMERIC := 0;

    emissao_amortizada_total NUMERIC := 0;
    remocao_amortizada_total NUMERIC := 0;
    emissao_total_co2 NUMERIC := 0;
    emissao_total_biogenico NUMERIC := 0;
BEGIN

    IF fator_personalizado is true THEN 
        emissao_total_co2:= (area_mus * 0.484238); --Referencia: MCT 2010, Joly et al. 2012

        RETURN QUERY
        SELECT 
            null::NUMERIC, null::NUMERIC, null::NUMERIC, null::NUMERIC, null::NUMERIC, null::NUMERIC,
            null::NUMERIC, null::NUMERIC, null::NUMERIC, null::NUMERIC, null::NUMERIC,
            null::NUMERIC, null::NUMERIC, null::INT, null::NUMERIC, null::NUMERIC,
            null::NUMERIC, null::NUMERIC, null::NUMERIC, null::NUMERIC, null::NUMERIC,
            null::NUMERIC, null::NUMERIC,
            emissao_total_co2, 
            null::NUMERIC;

        RETURN;
    ELSE
    -- Buscar sigla do estado
    SELECT sigla INTO sigla_estado
    FROM lista_uf
    WHERE id = id_estado;

    SELECT bioma INTO tipo_bioma_anterior
    FROM lista_biomas
    WHERE id = id_bioma_anterior;

    SELECT bioma INTO tipo_bioma_posterior
    FROM lista_biomas
    WHERE id = id_bioma_posterior;

    -- Buscar SOCref
    SELECT "Cultura anual" INTO soc_ref
    FROM fatores_mudanca_solo
    WHERE uf = sigla_estado AND parametro = 'SOCref';

    -- Buscar nomes dos usos do solo
    SELECT uso_anterior INTO uso_anterior_nome
    FROM lista_uso_solo
    WHERE id = id_uso_anterior_solo;

    SELECT uso_anterior INTO uso_posterior_nome
    FROM lista_uso_solo
    WHERE id = id_uso_posterior_solo;

    -- FLU, FMG, FI - Anterior
    IF estoque_carbono_solo IS NULL THEN
        IF uso_anterior_nome = 'Vegetacao natural' THEN
            FLU_anterior := 1;
            FMG_anterior := 1;
            FI_anterior := 1;
        ELSE
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''FLU''', uso_anterior_nome) INTO FLU_anterior USING sigla_estado;
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''FMG''', uso_anterior_nome) INTO FMG_anterior USING sigla_estado;
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''FI''', uso_anterior_nome) INTO FI_anterior USING sigla_estado;
        END IF;
    END IF;

    -- Carbono Solo Anterior
    IF estoque_carbono_solo IS NULL THEN
        carbono_solo_anterior := FLU_anterior * FI_anterior * FMG_anterior * soc_ref;
    ELSE
        carbono_solo_anterior := estoque_carbono_solo;
    END IF;

    -- Carbono Biomassa Anterior
    IF estoque_carbono_biomassa IS NOT NULL THEN
        carbono_biomassa_anterior := estoque_carbono_biomassa;
    ELSE
        IF uso_anterior_nome = 'Vegetacao natural' THEN
            IF NOT fitonomia_anterior THEN
                EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''Cveg''', detalhamento_vegetacao)
                INTO carbono_biomassa_anterior USING sigla_estado;
            ELSE
                IF tipo_bioma_anterior is NULL THEN
                    carbono_biomassa_anterior:=0;

                ELSIF lower(tipo_bioma_anterior) = 'cerrado' THEN
                    -- Cerrado tem coluna 'estado', precisa filtrar por sigla_estado
                    EXECUTE format(
                        'SELECT "estoque_total (tC/ha)" FROM lista_biomas_%s WHERE bioma = $1 AND estado = $2',
                        lower(tipo_bioma_anterior)
                    )
                    INTO carbono_biomassa_anterior
                    USING detalhamento_vegetacao, sigla_estado;
                ELSE
                    -- Outros biomas não têm a coluna 'estado'
                    EXECUTE format(
                        'SELECT "estoque_total (tC/ha)" FROM lista_biomas_%s WHERE bioma = $1',
                        lower(tipo_bioma_anterior)
                    )
                    INTO carbono_biomassa_anterior
                    USING detalhamento_vegetacao;
                END IF;
            END IF;
        ELSE
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''Cveg''', uso_anterior_nome)
            INTO carbono_biomassa_anterior USING sigla_estado;
        END IF;
    END IF;

    estoque_total_anterior := carbono_solo_anterior + carbono_biomassa_anterior;

    -- FLU, FMG, FI - Posterior
    IF estoque_carbono_solo IS NULL THEN
        IF uso_posterior_nome = 'Vegetacao natural' THEN
            FLU_posterior := 1;
            FMG_posterior := 1;
            FI_posterior := 1;
        ELSIF uso_posterior_nome = 'Assentamentos' THEN 
            FLU_posterior := 0.8 * FLU_anterior;
            FMG_posterior := 0.8 * FMG_anterior;
            FI_posterior := 0.8 * FI_anterior;
        ELSIF uso_posterior_nome = 'Outros usos' THEN 
            FLU_posterior := 0;
            FMG_posterior := 0;
            FI_posterior := 0;
        ELSE
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''FLU''', uso_posterior_nome) INTO FLU_posterior USING sigla_estado;
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''FMG''', uso_posterior_nome) INTO FMG_posterior USING sigla_estado;
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''FI''', uso_posterior_nome) INTO FI_posterior USING sigla_estado;
        END IF;
    END IF;

    -- Carbono Solo Posterior
    IF estoque_carbono_solo IS NULL THEN
        carbono_solo_posterior := FLU_posterior * FI_posterior * FMG_posterior * soc_ref;
    ELSE
        carbono_solo_posterior := 0;
    END IF;

    -- Carbono Biomassa Posterior
    IF estoque_carbono_biomassa IS NOT NULL THEN
        carbono_biomassa_posterior := estoque_carbono_biomassa;
    ELSE
        IF uso_posterior_nome in('Assentamentos', 'Outros usos') THEN 
            carbono_biomassa_posterior := 0;
        ELSIF uso_posterior_nome = 'Vegetacao natural' THEN
            IF NOT fitonomia_posterior THEN
                EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''Cveg''', detalhamento_vegetacao)
                INTO carbono_biomassa_posterior USING sigla_estado;
            ELSE
                IF tipo_bioma_posterior is NULL THEN
                    carbono_biomassa_posterior:= 0;
                ELSIF lower(tipo_bioma_posterior) = 'cerrado' THEN
                    -- Cerrado tem coluna 'estado', precisa filtrar por sigla_estado
                    EXECUTE format(
                        'SELECT "estoque_total (tC/ha)" FROM lista_biomas_%s WHERE bioma = $1 AND estado = $2',
                        lower(tipo_bioma_posterior)
                    )
                    INTO carbono_biomassa_posterior
                    USING detalhamento_vegetacao, sigla_estado;
                ELSE
                    -- Outros biomas não têm a coluna 'estado'
                    EXECUTE format(
                        'SELECT "estoque_total (tC/ha)" FROM lista_biomas_%s WHERE bioma = $1',
                        lower(tipo_bioma_posterior)
                    )
                    INTO carbono_biomassa_posterior
                    USING detalhamento_vegetacao;
                END IF;
            END IF;
        ELSE
            EXECUTE format('SELECT "%s" FROM fatores_mudanca_solo WHERE uf = $1 AND parametro = ''Cveg''', uso_posterior_nome)
            INTO carbono_biomassa_posterior USING sigla_estado;
        END IF;
    END IF;

    estoque_total_posterior := carbono_solo_posterior + carbono_biomassa_posterior;
    
    -- Cálculos finais
    emissao_absoluta_solo := greatest((carbono_solo_anterior - carbono_solo_posterior) * area_mus * 3.66666666666667 ,0);

    IF ((carbono_solo_anterior - carbono_solo_posterior) * 3.66666666666667 * area_mus) < 0 then
        remocao_absoluta_solo := -1 * (carbono_solo_anterior - carbono_solo_posterior) * 3.66666666666667 * area_mus;
    else
        remocao_absoluta_solo := 0;
    end if;
    
    periodo_amortizacao_solo := CASE WHEN id_uso_anterior_solo IS NULL THEN 0 ELSE 1 END;

    IF emissao_absoluta_solo = 0 then
        emissao_reportar_solo := 0;
    else
        emissao_reportar_solo := CASE WHEN periodo_amortizacao_solo = 0 THEN 0 ELSE emissao_absoluta_solo / periodo_amortizacao_solo END;
    end if;


    IF remocao_absoluta_solo = 0 then
        remocao_amortizada_solo := 0;
    else
        remocao_amortizada_solo := CASE WHEN periodo_amortizacao_solo = 0 THEN 0 ELSE remocao_absoluta_solo / periodo_amortizacao_solo END;
    end if;


    emissao_absoluta_biomassa := (carbono_biomassa_anterior - carbono_biomassa_posterior) * 3.66666666666667 * area_mus;
    
    IF ((carbono_biomassa_anterior - carbono_biomassa_posterior) * 3.66666666666667 * area_mus) < 0 then
        remocao_absoluta_biomassa := -1 * (carbono_biomassa_anterior - carbono_biomassa_posterior) * 3.66666666666667 * area_mus;
    else
        remocao_absoluta_biomassa := 0;
    end if;


    IF id_uso_posterior_solo IS NULL THEN
        periodo_amortizacao_biomassa := 0;
    ELSIF remocao_absoluta_biomassa = 0 THEN
        periodo_amortizacao_biomassa := 1;
    ELSIF uso_posterior_nome IN ('Vegetacao natural', 'Silvicultura') THEN
        periodo_amortizacao_biomassa := 20;
    ELSE
        periodo_amortizacao_biomassa := 1;
    END IF;

    emissao_reportar_biomassa := CASE WHEN periodo_amortizacao_biomassa = 0 THEN 0 ELSE emissao_absoluta_biomassa / periodo_amortizacao_biomassa END;
    
    remocao_reportar_amortizada_biomassa := CASE WHEN periodo_amortizacao_biomassa = 20 THEN remocao_absoluta_biomassa / periodo_amortizacao_biomassa ELSE 0 END;
    remocao_reportar_biomassa := CASE WHEN periodo_amortizacao_biomassa = 20 THEN 0 ELSE remocao_absoluta_biomassa / periodo_amortizacao_biomassa END;



    emissao_amortizada_total := greatest((emissao_reportar_solo + emissao_reportar_biomassa) - (remocao_amortizada_solo + remocao_reportar_biomassa + remocao_reportar_amortizada_biomassa),0);
    remocao_amortizada_total := greatest((remocao_amortizada_solo + remocao_reportar_biomassa + remocao_reportar_amortizada_biomassa) - (emissao_reportar_solo + emissao_reportar_biomassa), 0);

    IF uso_anterior_nome = 'Vegetacao natural' AND tipo_vegetacao_anterior = 'Primaria' THEN
        emissao_total_co2 := emissao_amortizada_total;
        emissao_total_biogenico := 0;
    ELSE
        emissao_total_co2 := 0;
        emissao_total_biogenico := emissao_amortizada_total;
    END IF;

    RETURN QUERY
        SELECT soc_ref, FLU_anterior, FMG_anterior,FI_anterior, carbono_solo_anterior, carbono_biomassa_anterior, FLU_posterior, FMG_posterior,FI_posterior, carbono_solo_posterior, carbono_biomassa_posterior, emissao_absoluta_solo, remocao_absoluta_solo, periodo_amortizacao_solo, emissao_reportar_solo, remocao_amortizada_solo, emissao_absoluta_biomassa, remocao_absoluta_biomassa, emissao_reportar_biomassa, remocao_reportar_biomassa, remocao_reportar_amortizada_biomassa, emissao_amortizada_total, remocao_amortizada_total, emissao_total_co2, emissao_total_biogenico;

    END if;
END;
$$ LANGUAGE plpgsql;

