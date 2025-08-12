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


## Examples and Use Cases

See in folder docs/examples.md

### Initial Setup Commands

Set kcctl context and verify installation:

```bash
kcctl config set-context local --cluster http://localhost:8083
kcctl info
kcctl get plugins --types=sink
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