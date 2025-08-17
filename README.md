# Self-Hosted PostgreSQL with pgAdmin

A simple Docker Compose setup for running PostgreSQL with pgAdmin web interface.

## Quick Start

1. Clone this repository
2. Copy and configure environment variables:

   ```bash
   # The .env file is already configured with default values
   # Edit .env to customize your credentials
   ```

3. Start the services:

   ```bash
   docker compose up -d
   ```

## Configuration

All credentials are stored in the `.env` file:
- `POSTGRES_USER`: Database username
- `POSTGRES_PASSWORD`: Database password  
- `POSTGRES_DB`: Database name
- `PGADMIN_DEFAULT_EMAIL`: pgAdmin login email
- `PGADMIN_DEFAULT_PASSWORD`: pgAdmin login password

## Access

### PostgreSQL Database
- **Host:** localhost
- **Port:** 5432
- **Database:** (check `POSTGRES_DB` in .env)
- **Username:** (check `POSTGRES_USER` in .env)
- **Password:** (check `POSTGRES_PASSWORD` in .env)

### pgAdmin Web Interface
- **URL:** http://localhost:15433
- **Email:** (check `PGADMIN_DEFAULT_EMAIL` in .env)
- **Password:** (check `PGADMIN_DEFAULT_PASSWORD` in .env)

### Connect pgAdmin to PostgreSQL

1. Open pgAdmin at <http://localhost:15433>
2. Add new server with these connection details:
   - **Host:** `database` (Docker service name)
   - **Port:** 5432
   - **Username:** (check `POSTGRES_USER` in .env)
   - **Password:** (check `POSTGRES_PASSWORD` in .env)
   - **Database:** (check `POSTGRES_DB` in .env)

## Commands

### Basic Operations
```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs

# Check container status
docker compose ps
```

### Database Operations
```bash
# Connect to PostgreSQL directly
docker exec -it selfhostpg-database-1 psql -U postgres_user -d myapp_db

# Backup database
docker exec selfhostpg-database-1 pg_dump -U postgres_user myapp_db > backup.sql

# Restore database
docker exec -i selfhostpg-database-1 psql -U postgres_user myapp_db < backup.sql

# Use the automated backup script
./backup.sh
```

### Recreate Containers

When you need to recreate containers (e.g., after changing credentials):

#### Option 1: Recreate containers only (keeps data)

```bash
docker compose down
docker compose up -d --force-recreate
```

#### Option 2: Recreate specific service

```bash
# For pgAdmin only (useful when changing pgAdmin credentials)
docker compose stop pgadmin
docker compose rm pgadmin
docker volume rm selfhostpg_pgadmin_data  # Removes pgAdmin settings
docker compose up pgadmin -d

# For database only
docker compose stop database
docker compose rm database
docker compose up database -d
```

#### Option 3: Complete rebuild (⚠️ DELETES ALL DATA)

```bash
# WARNING: This will delete all your database data!
docker compose down -v  # -v removes volumes
docker compose up -d
```

#### Option 4: Fresh start with new environment variables
```bash
# After modifying .env file
docker compose down
docker compose rm  # Remove containers
docker compose up -d --force-recreate
```

### Troubleshooting

If pgAdmin login fails after changing credentials:
```bash
docker compose stop pgadmin
docker compose rm pgadmin
docker volume rm selfhostpg_pgadmin_data
docker compose up pgadmin -d
```

If PostgreSQL won't start:
```bash
docker compose logs database
# Check for permission or configuration issues
```

## Data Persistence

Data is stored in Docker named volumes:

- `postgres_data`: PostgreSQL database files
- `pgadmin_data`: pgAdmin configuration and settings
