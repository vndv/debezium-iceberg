set context:
```kcctl config set-context local --cluster http://localhost:8083```

```kcctl info```

```kcctl get plugins --types=sink```

load example data to kafka and see topic
```
echo '{"order_id": "001", "customer_id": "cust_123", "product": "laptop", "quantity": 1, "price": 999.99}
{"order_id": "002", "customer_id": "cust_456", "product": "mouse", "quantity": 2, "price": 25.50}
{"order_id": "003", "customer_id": "cust_789", "product": "keyboard", "quantity": 1, "price": 75.00}
{"order_id": "004", "customer_id": "cust_321", "product": "monitor", "quantity": 1, "price": 299.99}
{"order_id": "005", "customer_id": "cust_654", "product": "headphones", "quantity": 1, "price": 149.99}' | docker compose exec -T kcat kcat -P -b broker:9092 -t orders
```

- apply iceberg-sink and see data in trino tables
```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-kc_orders",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "orders",

    "iceberg.tables": "default.orders",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "iceberg.control.commit.interval-ms": "1000",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false"
  }
}'
```

write another row to order topic
```
echo '{"order_id": "006", "customer_id": "cust_987", "product": "webcam", "quantity": 1, "price": 89.99}' | docker compose exec -T kcat kcat -P -b broker:9092 -t orders
```

write click dataset

```
echo '{"click_ts": "2023-02-01T14:30:25Z","ad_cost": "1.50","is_conversion": "true","user_id": "001234567890"}' | docker compose exec -T kcat kcat -P -b broker:9092 -t clicks
```

- iceberg-sink clicks for see data in trino, and we can see problems with data type for clicl_ts now it is varchar but we need timestamp, we need schema

```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-kc_clicks",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "clicks",
    "iceberg.tables": "default.clicks",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "iceberg.control.commit.interval-ms": "1000"
  }
}'
```

-- topic with schema for fix problem with timestamp data type

```
echo '{
  "schema": {
    "type": "struct",
    "fields": [
      {"field": "click_ts", "type": "int64", "name": "org.apache.kafka.connect.data.Timestamp", "version": 1, "optional": false},
      {"field": "ad_cost", "type": "bytes", "name": "org.apache.kafka.connect.data.Decimal", "version": 1, "parameters": {"scale": "2"}, "optional": false},
      {"field": "is_conversion", "type": "boolean", "optional": false},
      {"field": "user_id", "type": "string", "optional": false}
    ]
  },
  "payload": {
    "click_ts": 1675258225000,
    "ad_cost": "AJY=",
    "is_conversion": true,
    "user_id": "001234567890"
  }
}' | jq -c . | docker compose exec -T kcat kcat -P -b broker:9092 -t clicks_with_schema


```

- iceberg-sink whit schema for correct data types in timstamp field

```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-kc_clicks_schema",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "clicks_with_schema",
    "iceberg.tables": "default.clicks_embedded_schema",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "true",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true",
    "iceberg.control.commit.interval-ms": "1000"
  }
}'
```

- create postgres table with some data

```
CREATE TABLE public.clicks (
    click_ts TIMESTAMP WITH TIME ZONE,
    ad_cost DECIMAL(38,2),
    is_conversion BOOLEAN,
    user_id VARCHAR
);

INSERT INTO public.clicks (click_ts, ad_cost, is_conversion, user_id)
    VALUES ('2023-02-01 13:30:25+00', 1.50, true, '001234567890');
```


- apply debezium for postgres

```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "postgres-clicks-source-avro",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",

    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "Welcome123",
    "database.dbname": "postgres",

    "table.include.list": "public.clicks",

    "topic.prefix": "dbz-avro",

    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'
```

- iceberg-sink for cdc postgres

```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-clicks",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "dbz-avro.public.clicks",
    "iceberg.tables": "default.postgres_clicks",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "iceberg.control.commit.interval-ms": "1000",
    "transforms": "dbz",
    "transforms.dbz.type": "io.tabular.iceberg.connect.transforms.DebeziumTransform"
  }
}'
```

- iceberg-sink with correct datatype for timstamp
this doesnt work for curl post
```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-clicks-new",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "dbz-avro.public.clicks",

    "iceberg.tables": "default.postgres_clicks",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "iceberg.control.commit.interval-ms": "1000",

    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",

    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",

    
    "transforms": "dbz,convert_ts", 
    "transforms.dbz.type": "io.tabular.iceberg.connect.transforms.DebeziumTransform",
    "transforms.convert_ts.type" : "org.apache.kafka.connect.transforms.TimestampConverter$Value",
    "transforms.convert_ts.field" : "click_ts",
    "transforms.convert_ts.format": "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
    "transforms.convert_ts.target.type": "Timestamp"
  }
}'
```



-- this example works
```
kcctl apply -f - <<EOF
{
  "name": "iceberg-sink-postgres-clicks-new",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "dbz-avro.public.clicks",
    "iceberg.tables": "default.postgres_clicks",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "iceberg.control.commit.interval-ms": "1000",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "transforms": "dbz,convert_ts", 
    "transforms.dbz.type": "io.tabular.iceberg.connect.transforms.DebeziumTransform",
    "transforms.convert_ts.type" : "org.apache.kafka.connect.transforms.TimestampConverter\$Value",
    "transforms.convert_ts.field" : "click_ts",
    "transforms.convert_ts.format": "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
    "transforms.convert_ts.target.type": "Timestamp"
  }
}
EOF
```

--evolve schema iceberg sink

```
kcctl apply -f - <<EOF
{
  "name": "iceberg-sink-postgres-clicks01",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "dbz-avro.public.clicks",
    "iceberg.tables": "default.postgres_clicks",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.tables.evolve-schema-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "iceberg.control.commit.interval-ms": "1000",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "iceberg.control.commit.interval-ms": "1000",
    "transforms": "dbz,convert_ts",
    "transforms.dbz.type": "io.tabular.iceberg.connect.transforms.DebeziumTransform",
    "transforms.convert_ts.type" : "org.apache.kafka.connect.transforms.TimestampConverter\$Value",
    "transforms.convert_ts.field" : "click_ts",
    "transforms.convert_ts.format": "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
    "transforms.convert_ts.target.type": "Timestamp"
  }
}
EOF
```

-- multiply table in postgres europe

```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "postgres-europe",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "Welcome123",
    "database.dbname": "postgres",
    "schema.include.list": "europe",
    "topic.prefix": "dbz-avro",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'
```

-- multiply table in postgres asia

```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "postgres-asia",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "Welcome123",
    "database.dbname": "postgres",
    "schema.include.list": "asia",
    "topic.prefix": "cdc",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'
```


-- send data to iceberg with dynamic-routing
```
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-europe",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics.regex": "dbz-avro.europe.*",
    "iceberg.tables.dynamic-enabled": "true",
    "iceberg.tables.route-field":"_cdc.target",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.tables.evolve-schema-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "iceberg.control.commit.interval-ms": "1000",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "iceberg.control.commit.interval-ms": "1000",
    "transforms": "dbz",
    "transforms.dbz.type": "io.tabular.iceberg.connect.transforms.DebeziumTransform",
    "transforms.dbz.cdc.target.pattern": "default.{db}_{table}"
  }
}'
```


- unpuck data to iceberg

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-asia",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics.regex": "cdc.asia.*",
    "iceberg.tables.dynamic-enabled": "true",
    "iceberg.tables.route-field": "_cdc_target",
    "iceberg.tables.auto-create-enabled": "true",
    "iceberg.tables.evolve-schema-enabled": "true",
    "iceberg.catalog.type": "hive",
    "iceberg.catalog.uri": "thrift://hive-metastore:9083",
    "iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
    "iceberg.catalog.warehouse": "s3://datalake/",
    "iceberg.catalog.client.region": "eu-west-1",
    "iceberg.catalog.s3.access-key-id": "minio",
    "iceberg.catalog.s3.secret-access-key": "minio123",
    "iceberg.catalog.s3.endpoint": "http://minio:9000",
    "iceberg.catalog.s3.path-style-access": "true",
    "iceberg.control.commit.interval-ms": "1000",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "iceberg.control.commit.interval-ms": "1000",
    "transforms": "debeziumTransform,flatten,dropField,insertField,renameTarget",
    "transforms.debeziumTransform.cdc.target.pattern": "cdc.{db}_{table}",
    "transforms.debeziumTransform.type": "io.tabular.iceberg.connect.transforms.DebeziumTransform",

    "transforms.extractTs.input.inner.field.name": "ts",
    "transforms.extractTs.input.outer.field.name": "_cdc",
    "transforms.extractTs.output.field.name": "_cdc_timestamp",
    "transforms.extractTs.type": "com.github.jcustenborder.kafka.connect.transform.common.ExtractNestedField$Value",
    "transforms.flatten.type": "org.apache.kafka.connect.transforms.Flatten$Value",
    "transforms.flatten.delimiter": "_",

    "transforms.dropField.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",
    "transforms.dropField.exclude": "_cdc_target",

    "transforms.insertField.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.insertField.topic.field": "_cdc_target",

    "transforms.renameTarget.type": "com.github.jcustenborder.kafka.connect.transform.common.PatternMapString$Value",
    "transforms.renameTarget.src.field.name": "_cdc_target",
    "transforms.renameTarget.dest.field.name": "_cdc_target",
    "transforms.renameTarget.value.pattern": "cdc\\.(.+)\\.(.+)\\.(.+)",
    "transforms.renameTarget.value.replacement": "cdc.$1_$2_$3"
  }
}'
```