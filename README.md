# Debezium-Iceberg Integration Project

This project demonstrates how to integrate Debezium with Apache Iceberg using Kafka Connect, providing a complete CDC (Change Data Capture) pipeline that captures changes from PostgreSQL and writes them to Iceberg tables stored in MinIO.

## Overview

The project showcases:
- Streaming data from Kafka topics to Iceberg tables
- CDC from PostgreSQL using Debezium connectors
- Schema management with Avro and Schema Registry
- Data transformation and type conversion
- Dynamic table routing for multi-schema scenarios

## Architecture

- **Kafka**: Message broker for streaming data
- **Debezium**: CDC connector for PostgreSQL
- **Iceberg**: Table format for data lake storage
- **MinIO**: S3-compatible object storage
- **Hive Metastore**: Metadata management for Iceberg
- **Trino**: Query engine for analytics
- **Schema Registry**: Schema management for Avro

## Getting Started

### Prerequisites

- Docker and Docker Compose
- kcctl (Kafka Connect CLI tool)

### Quick Start

Use the provided Makefile for easy project management:

```bash
# Download Iceberg connector and setup project
make setup

# Start all services
make up

# Set kcctl context
make context

# View service status
make ps

# View logs
make logs

# Stop all services
make down

# Clean all data (removes volumes and downloaded connectors)
make clean
```

### Available Makefile Commands

| Command | Description |
|---------|-------------|
| `make setup` | Download Iceberg connector and prepare project |
| `make up` | Start all services with Docker Compose |
| `make down` | Stop all services |
| `make restart` | Restart all services |
| `make ps` | Show service status |
| `make logs` | View logs (follows) |
| `make clean` | Remove all data, volumes, and downloaded files |
| `make context` | Set kcctl context for local cluster |
| `make help` | Show available commands |

## Examples and Use Cases

### Initial Setup Commands

Set kcctl context and verify installation:

```bash
kcctl config set-context local --cluster http://localhost:8083
kcctl info
kcctl get plugins --types=sink
```

### 1. Basic Kafka to Iceberg Integration

Load example data to Kafka and create Iceberg sink:
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

### 4. Advanced Transformations

**Iceberg sink with timestamp conversion (this example shows curl limitations with complex transforms):**
```bash
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



**Working solution using kcctl for complex transformations:**
```bash
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

**Schema evolution example:**

```bash
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
    "transforms.renameTarget.value.pattern": "cdc\\.(.+)\\.(.+)\\.(.+)",
    "transforms.renameTarget.value.replacement": "cdc.$1_$2_$3"
  }
}'
```

## Key Features Demonstrated

1. **Basic Integration**: Simple Kafka topics to Iceberg tables
2. **Schema Management**: Handling data types and schema evolution
3. **CDC Integration**: Real-time change capture from PostgreSQL
4. **Data Transformations**: Converting timestamps and other data types
5. **Dynamic Routing**: Multi-schema environments with automatic table routing
6. **Complex Transformations**: Flattening, field extraction, and pattern-based transformations

## Configuration Highlights

- **Iceberg Catalog**: Hive Metastore with S3-compatible storage (MinIO)
- **Schema Registry**: Avro schema management for type safety
- **Debezium Transforms**: Built-in CDC data transformations
- **Custom Transforms**: Timestamp conversion and field manipulation
- **Dynamic Tables**: Automatic table creation and schema evolution

## Troubleshooting

- Use `kcctl` instead of curl for complex connector configurations
- Enable schema evolution for dynamic schema changes
- Monitor connector status: `kcctl get connectors`
- Check connector logs: `make logs`
- Verify data in Trino for validation

## Project Structure

```
debezium-iceberg/
├── connectors/                 # Downloaded Kafka Connect plugins
├── docker-compose.yml         # Infrastructure services
├── Makefile                   # Project management commands
├── pg.sql                     # PostgreSQL setup scripts
├── README.md                  # This documentation
├── scripts.sh/                # Additional scripts
└── trino/                     # Trino configuration
    └── catalog/
        └── iceberg.properties
```