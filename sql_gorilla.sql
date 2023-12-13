-- Crear la secuencia

CREATE SEQUENCE IF NOT EXISTS esquema_gorilla.alarms_id_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 65535000
    NO CYCLE;

-- Crear el esquema para las particiones
CREATE SCHEMA IF NOT EXISTS esquema_gorilla_part;

-- Crear la tabla particionada en el nuevo esquema
CREATE TABLE IF NOT EXISTS esquema_gorilla.alarms
(
    id bigint DEFAULT nextval('esquema_gorilla.alarms_id_seq'::regclass) NOT NULL,
    description varchar(10),
    date_alarm timestamp,
    alarm_type varchar(2),
    alarm_criticality varchar(2),
    alarm_status varchar(2),
    PRIMARY KEY (id, date_alarm)
);

-- Crear la partición para cada día en el nuevo esquema
DO $$ 
DECLARE
    start_date timestamp := '2023-01-01 00:00:00';
    end_date timestamp := '2023-12-31 23:59:59';
    current_date timestamp := start_date;
BEGIN
    LOOP
        EXIT WHEN current_date > end_date;
        
        EXECUTE format('CREATE TABLE IF NOT EXISTS esquema_gorilla_part.alarms_%s PARTITION OF esquema_gorilla.alarms FOR VALUES FROM (%L) TO (%L)', 
                       TO_CHAR(current_date, 'YYYYMMDD'), current_date, current_date + interval '1 day');
        
        current_date := current_date + interval '1 day';
    END LOOP;
END $$;

-- Habilitar la compresión Gorilla en la tabla
SELECT create_hypertable(
    'esquema_gorilla.alarms', 
    'date_alarm',  
    chunk_time_interval => interval '1 day',   
    associated_schema_name => 'esquema_gorilla_part', 
    associated_table_prefix => 'alarms',
    if_not_exists => true
);

-- Crear la función PL/pgSQL en el nuevo esquema
CREATE OR REPLACE FUNCTION esquema_gorilla.insert_random_alarm_with_random_dates()
    RETURNS VOID AS
$$
DECLARE
    descriptions varchar[] := ARRAY['Desc1', 'Desc2', 'Desc3'];
    alarm_types varchar[] := ARRAY['A1', 'A2', 'A3'];
    criticalities varchar[] := ARRAY['C1', 'C2', 'C3'];
    statuses varchar[] := ARRAY['S1', 'S2', 'S3'];
    random_date timestamp;
BEGIN
    -- Bucle para insertar valores aleatorios con pausa entre iteraciones
    FOR i IN 1..2000000 LOOP  -- Ajusta el número de iteraciones según tus necesidades
        -- Generar una fecha aleatoria dentro del rango deseado
        random_date := NOW() - (random() * interval '365 days');

        INSERT INTO esquema_gorilla.alarms (description, date_alarm, alarm_type, alarm_criticality, alarm_status)
        VALUES (
            descriptions[ceil(random() * array_length(descriptions, 1))],
            random_date,
            alarm_types[ceil(random() * array_length(alarm_types, 1))],
            criticalities[ceil(random() * array_length(criticalities, 1))],
            statuses[ceil(random() * array_length(statuses, 1))]
        );

        -- Pausa de 10 segundos entre iteraciones
        --PERFORM pg_sleep(1);
    END LOOP;
END;
$$
LANGUAGE plpgsql;

-- Llamar a la función para insertar alarmas con fechas aleatorias y pausas
SELECT esquema_gorilla.insert_random_alarm_with_random_dates();
