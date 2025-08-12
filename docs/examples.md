### 1. Basic Kafka to Iceberg Integration

**Load example data to Kafka and create Iceberg sink:**

```bash
echo '{"order_id": "001", "customer_id": "cust_123", "product": "laptop", "quantity": 1, "price": 999.99}
{"order_id": "002", "customer_id": "cust_456", "product": "mouse", "quantity": 2, "price": 25.50}
{"order_id": "003", "customer_id": "cust_789", "product": "keyboard", "quantity": 1, "price": 75.00}
{"order_id": "004", "customer_id": "cust_321", "product": "monitor", "quantity": 1, "price": 299.99}
{"order_id": "005", "customer_id": "cust_654", "product": "headphones", "quantity": 1, "price": 149.99}' | docker compose exec -T kcat kcat -P -b broker:9092 -t orders
```

**Create Iceberg sink connector for orders topic:**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-orders",
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

**Add another record to orders topic:**

```bash
echo '{"order_id": "006", "customer_id": "cust_987", "product": "webcam", "quantity": 1, "price": 89.99}' | docker compose exec -T kcat kcat -P -b broker:9092 -t orders
```

### 2. Working with Schemas and Data Types

**Send click data (without schema):**

```bash
echo '{"click_ts": "2023-02-01T14:30:25Z","ad_cost": "1.50","is_conversion": "true","user_id": "001234567890"}' | docker compose exec -T kcat kcat -P -b broker:9092 -t clicks
```

**Create Iceberg sink for clicks (demonstrates data type issues without schema):**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-clicks",
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

**Send data with embedded schema to fix timestamp data type issues:**

```bash
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

**Create Iceberg sink with schema enabled for proper timestamp handling:**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-clicks_schema",
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

### 3. PostgreSQL CDC with Debezium

**Create PostgreSQL table with sample data:**

```sql
CREATE TABLE public.clicks (
    click_ts TIMESTAMP WITH TIME ZONE,
    ad_cost DECIMAL(38,2),
    is_conversion BOOLEAN,
    user_id VARCHAR
);

INSERT INTO public.clicks (click_ts, ad_cost, is_conversion, user_id)
    VALUES ('2023-02-01 13:30:25+00', 1.50, true, '001234567890');
```

**Configure Debezium PostgreSQL source connector without Avro:**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
    "name": "postgres-clicks-source",
    "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",

    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "postgres",

    "table.include.list": "public.clicks",

    "topic.prefix": "dbz",
    "plugin.name": "pgoutput",
    "snapshot.mode": "initial",
    "slot.name": "default_pub"

  }
}'
```

**Create Iceberg sink for PostgreSQL CDC raw data:**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
    "name": "iceberg-sink-postgres-clicks-raw",
    "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "dbz.public.clicks",
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
    "iceberg.control.commit.interval-ms": "1000"
  }
}'
```

**Configure Debezium PostgreSQL source connector with Avro:**

```bash
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
    "database.password": "postgres",
    "database.dbname": "postgres",

    "table.include.list": "public.clicks",

    "topic.prefix": "dbz-avro",
    "plugin.name": "pgoutput",
    "snapshot.mode": "initial",
    "slot.name": "default_pub",

    "tombstones.on.delete": "false",

    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'
```

**Create Iceberg sink for PostgreSQL CDC data:**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-clicks",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics": "dbz-avro.public.clicks",
    "iceberg.tables": "default.postgres_clicks_avro",
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

### 4. Advanced Transformations


**Schema evolution example:**

```sql
ALTER TABLE clicks ADD COLUMN campaign_id character varying;

INSERT INTO clicks (click_ts, ad_cost, is_conversion, user_id, campaign_id)
    VALUES ('2025-07-03 14:30:00+00', 2.50, true, 'user_12345', 'campaign_summer_2025');
```


### 5. Multi-Schema and Dynamic Routing

**Configure Debezium for Europe schema:**

```bash
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
    "database.password": "postgres",
    "database.dbname": "postgres",
    "schema.include.list": "europe",
    "topic.prefix": "dbz-avro",
    "plugin.name": "pgoutput",
    "snapshot.mode": "initial",
    "slot.name": "europe_pub",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'
```

**Iceberg sink with dynamic routing for Europe tables:**
```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-europe",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics.regex": "dbz-avro.europe.*",
    "iceberg.tables.dynamic-enabled": "true",
    "iceberg.tables.route-field": "_cdc.target",
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



**Configure Debezium for Asia schema:**

```bash
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
    "database.password": "postgres",
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

**Advanced data unpacking to Iceberg with complex transformations:**

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
    "transforms.renameTarget.value.pattern": "cdc\\.(.+)\\.(.+)",
    "transforms.renameTarget.value.replacement": "cdc.$1_$2"
  }
}'

**N:1 (Fan In / Writing many topics to one table)**

curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "postgres-orders",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "postgres",
    "table.include.list": ".*orders",
    "topic.prefix": "dbz-avro",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'

**Iceberg sink with dynamic routing for multy fun-out:**

curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-orders",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics.regex": "dbz-avro..*orders",
    "iceberg.tables": "default.orders",
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
    "transforms.dbz.type": "io.tabular.iceberg.connect.transforms.DebeziumTransform"
  }
}'


**Configure Debezium for US-East schema:**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "postgres-us-east",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "postgres",
    "schema.include.list": "us_east",
    "topic.prefix": "dbz-avro",
    "plugin.name": "pgoutput",
    "snapshot.mode": "initial",
    "slot.name": "us_east_pub",

    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "true",
    "transforms.unwrap.delete.handling.mode": "drop",

    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'
```

**Iceberg sink with dynamic routing for US-East tables:**

```bash
curl -X POST \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' http://localhost:8083/connectors \
	-d '{
  "name": "iceberg-sink-postgres-us-east",
  "config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "topics.regex": "dbz-avro.us_east.*",
    
    "iceberg.tables": "default.us_east_orders",
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
    "iceberg.control.commit.interval-ms": "1000"
  }
}'
```




