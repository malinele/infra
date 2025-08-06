# 🔧 PostgreSQL Troubleshooting Guide

## ❌ PostgreSQL Not Starting? Here's How to Fix It!

### 🎯 **Quick Fix Commands**

#### **Linux/Mac:**
```bash
# Run the automated fix script
./scripts/fix-postgres.sh

# Or manual fix
docker-compose stop postgres
docker-compose rm -f postgres
docker volume prune -f
docker-compose up -d postgres
```

#### **Windows:**
```batch
# Run the automated fix script
scripts\fix-postgres.bat

# Or manual fix  
docker-compose stop postgres
docker-compose rm -f postgres
docker volume prune -f
docker-compose up -d postgres
```

### 🔍 **Common Issues & Solutions**

#### **1. Port 5432 Already in Use** ❌
**Problem:** Another PostgreSQL instance is running
```
Error: bind: address already in use
```

**Solutions:**
```bash
# Option A: Stop system PostgreSQL
sudo systemctl stop postgresql    # Linux
brew services stop postgresql     # Mac
net stop postgresql-x64-14        # Windows

# Option B: Use different port in docker-compose.yml
ports:
  - "5433:5432"  # Change to 5433
```

#### **2. Volume/Permission Issues** ❌
**Problem:** PostgreSQL can't write to data directory
```
Error: initdb: could not create directory
```

**Solution:**
```bash
# Remove volumes and restart fresh
docker-compose down -v
docker volume prune -f
docker-compose up -d postgres
```

#### **3. Init Script SQL Error** ❌
**Problem:** SQL syntax error in init-db.sql
```
Error: syntax error at or near "PRINT"
```

**Fixed:** ✅ The `PRINT` statement has been replaced with PostgreSQL-compatible syntax.

#### **4. Memory/Resource Issues** ❌
**Problem:** Not enough resources
```
Error: could not fork new process
```

**Solution:**
```bash
# Increase Docker Desktop memory allocation
# Docker Desktop → Settings → Resources → Memory: 4GB+
```

#### **5. Docker Network Issues** ❌
**Problem:** Network connectivity problems
```
Error: could not translate host name
```

**Solution:**
```bash
# Recreate network
docker network rm esport-coach-network
docker network create esport-coach-network
docker-compose up -d postgres
```

### 🧪 **Testing PostgreSQL Independently**

Use the test-only PostgreSQL setup:
```bash
# Test PostgreSQL alone
docker-compose -f test-postgres.yml up -d

# Check if it works
docker-compose -f test-postgres.yml exec postgres pg_isready -U admin

# Connect to test database
docker-compose -f test-postgres.yml exec postgres psql -U admin -d esport_coach

# Clean up test
docker-compose -f test-postgres.yml down -v
```

### 📊 **Health Check Commands**

```bash
# Check container status
docker ps | grep postgres

# Check health status
docker inspect esport-postgres --format='{{.State.Health.Status}}'

# View logs
docker logs esport-postgres --tail 50

# Test connection
docker exec esport-postgres pg_isready -U admin -d esport_coach

# Connect to database
docker exec -it esport-postgres psql -U admin -d esport_coach
```

### ✅ **Verification Steps**

After fixing, verify PostgreSQL is working:

1. **Container Running:**
   ```bash
   docker ps | grep esport-postgres
   # Should show "Up (healthy)"
   ```

2. **Database Connection:**
   ```bash
   docker exec esport-postgres pg_isready -U admin -d esport_coach
   # Should return "accepting connections"
   ```

3. **Tables Created:**
   ```bash
   docker exec esport-postgres psql -U admin -d esport_coach -c "\dt"
   # Should list all tables (users, coaches, etc.)
   ```

4. **Seed Data:**
   ```bash
   docker exec esport-postgres psql -U admin -d esport_coach -c "SELECT COUNT(*) FROM users;"
   # Should return count: 2
   ```

### 🛠️ **Advanced Troubleshooting**

#### **Debug Mode:**
```bash
# Run PostgreSQL with debug output
docker run --rm -it \
  -e POSTGRES_DB=esport_coach \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=admin123 \
  -p 5432:5432 \
  postgres:15-alpine \
  postgres -c log_statement=all
```

#### **Check PostgreSQL Configuration:**
```bash
# View current config
docker exec esport-postgres postgres --help

# Check data directory
docker exec esport-postgres ls -la /var/lib/postgresql/data/
```

#### **Reset Everything:**
```bash
# Nuclear option - removes all data
docker-compose down -v
docker system prune -f
docker volume prune -f
docker-compose up -d postgres
```

### 📋 **Environment Variables Reference**

| Variable | Value | Description |
|----------|-------|-------------|
| `POSTGRES_DB` | `esport_coach` | Database name |
| `POSTGRES_USER` | `admin` | Database user |
| `POSTGRES_PASSWORD` | `admin123` | Database password |
| `PGDATA` | `/var/lib/postgresql/data/pgdata` | Data directory |

### 🎯 **Connection Details**

- **Host:** `localhost` (or `postgres` from within Docker network)
- **Port:** `5432`
- **Database:** `esport_coach`
- **Username:** `admin`
- **Password:** `admin123`

### 🆘 **Still Not Working?**

If PostgreSQL still won't start after trying all solutions:

1. **Check Docker Desktop:**
   - Restart Docker Desktop
   - Increase memory allocation (Settings → Resources)
   - Check available disk space

2. **System Check:**
   - Reboot your computer
   - Update Docker Desktop
   - Check antivirus software isn't blocking Docker

3. **Alternative Database:**
   ```bash
   # Temporary SQLite fallback (for development only)
   # Modify services to use SQLite instead of PostgreSQL
   ```

4. **Ask for Help:**
   - Provide output of: `docker logs esport-postgres`
   - Provide output of: `docker-compose config`
   - System info: OS, Docker version, available memory

### ✨ **PostgreSQL is Fixed!**

Once PostgreSQL is running:
- ✅ Container shows "Up (healthy)"
- ✅ Port 5432 accepting connections
- ✅ Database `esport_coach` created
- ✅ All tables created with seed data
- ✅ Ready for application services

**Now you can start the full platform with confidence!** 🚀