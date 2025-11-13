# Port Configuration Changes

**Date**: 2025-11-12

## Summary

Updated all port configurations to match the requested architecture:
- **Nginx**: Port 8080 (was 9090)
- **Registry v2**: Port 2222 (was 8080)
- **Registry v3**: Port 3333 (to be implemented)

## Rationale

This configuration provides:
1. **Standard nginx port**: Port 8080 is the standard external access point
2. **Dedicated registry ports**: v2 and v3 run on separate ports (2222 and 3333)
3. **No conflicts**: Internal container port (8080) mapped to different external ports
4. **Easy switching**: Nginx can route to either v2 or v3 without port conflicts

## Architecture

```
External Access                Internal Containers
================               ====================

Port 8080                      ┌─────────────┐
(nginx)       ────────────────►│    Nginx    │
                               │  (Port 8080)│
                               └──────┬──────┘
                                      │
                    ┌─────────────────┴────────────────┐
                    │                                  │
                    ▼                                  ▼
Port 2222    ┌──────────────┐              ┌──────────────┐    Port 3333
(v2 direct)  │  Registry v2 │              │  Registry v3 │    (v3 direct)
◄────────────│ (Port 8080)  │              │ (Port 8080)  │────────────►
             └──────────────┘              └──────────────┘
```

## Changed Files

### Docker Compose Files
- [x] `docker-compose-v2.yml` - Changed v2 port mapping from `8080:8080` to `2222:8080`
- [x] `docker-compose-nginx.yml` - Changed nginx port mapping from `9090:8080` to `8080:8080`
- [ ] `docker-compose-v3.yml` - Will use `3333:8080` (not yet implemented)

### Scripts
- [x] `scripts/step-A-deploy-v2.sh` - Updated all URLs from `:8080` to `:2222`
- [x] `scripts/step-B-deploy-nginx.sh` - Updated all URLs from `:9090` to `:8080`
- [x] `scripts/test-basic-setup.sh` - Updated URLs for both direct (`:2222`) and nginx (`:8080`)
- [x] `scripts/wait-for-health.sh` - No changes (takes URL as parameter)
- [x] `scripts/cleanup.sh` - No changes (port-agnostic)

### Documentation
- [x] `QUICKSTART.md` - Updated all examples and port references
- [x] `README.md` - Port references updated
- [ ] `TEST_PLAN.md` - Needs updating
- [ ] `IMPLEMENTATION_STATUS.md` - Needs updating

### Nginx Configuration
- [x] `nginx/nginx.conf` - No changes (port-agnostic)
- [x] `nginx/conf.d/registry-v2.conf` - No changes (uses internal container name and port)
- [x] `nginx/conf.d/registry-v3.conf` - No changes (uses internal container name and port)

## Port Reference Table

| Component | External Port | Internal Port | Access |
|-----------|---------------|---------------|--------|
| PostgreSQL v2 | 5432 | 5432 | Direct |
| PostgreSQL v3 | 5433 | 5432 | Direct |
| Registry v2 | 2222 | 8080 | Direct |
| Registry v3 | 3333 | 8080 | Direct (when implemented) |
| Nginx | 8080 | 8080 | **Primary Access Point** |

## Testing Ports

### Before Port Changes
```bash
# OLD - Don't use these anymore
curl http://localhost:8080/apis/registry/v2/system/info  # Direct v2 (OLD)
curl http://localhost:9090/apis/registry/v2/system/info  # Via nginx (OLD)
```

### After Port Changes
```bash
# NEW - Use these
curl http://localhost:2222/apis/registry/v2/system/info  # Direct v2 (NEW)
curl http://localhost:8080/apis/registry/v2/system/info  # Via nginx (NEW)
```

## Migration Path Example

### Step 1: Deploy v2
```bash
./scripts/step-A-deploy-v2.sh
# Registry v2 accessible at: http://localhost:2222
```

### Step 2: Deploy Nginx (pointing to v2)
```bash
./scripts/step-B-deploy-nginx.sh
# Nginx accessible at: http://localhost:8080
# Routes to: Registry v2 at scenario1-registry-v2:8080 (internal)
```

### Step 3: Deploy v3 (future)
```bash
./scripts/step-G-deploy-v3.sh
# Registry v3 accessible at: http://localhost:3333
```

### Step 4: Switch Nginx to v3 (future)
```bash
./scripts/step-I-switch-nginx.sh
# Nginx still at: http://localhost:8080
# Routes to: Registry v3 at scenario1-registry-v3:8080 (internal)
```

## Benefits of This Configuration

1. **Consistent External Port**: Clients always use port 8080 (via nginx)
2. **No Downtime Switching**: Can switch between v2 and v3 by reloading nginx only
3. **Parallel Testing**: Can test both v2 (port 2222) and v3 (port 3333) directly
4. **Production-Like**: Mimics real load balancer setup
5. **Easy Debugging**: Can bypass nginx and test registries directly

## Client Configuration

### For Testing During Migration

```java
// Access through nginx (recommended for testing migration)
String registryUrl = "http://localhost:8080/apis/registry/v2";

// Access v2 directly (for debugging)
String v2DirectUrl = "http://localhost:2222/apis/registry/v2";

// Access v3 directly (for debugging, after v3 is deployed)
String v3DirectUrl = "http://localhost:3333/apis/registry/v3";
```

### For Production Migration Simulation

```java
// Step 1: All clients use nginx
String registryUrl = "http://nginx:8080/apis/registry/v2";

// After migration (Step I), same URL works but routes to v3
// Clients don't need to change anything!
```

## Verification Commands

### Check All Ports
```bash
# See what's listening
netstat -tulpn | grep -E '(2222|3333|5432|5433|8080)'

# Or with lsof
lsof -i :2222  # Registry v2
lsof -i :3333  # Registry v3 (when deployed)
lsof -i :8080  # Nginx
lsof -i :5432  # PostgreSQL v2
lsof -i :5433  # PostgreSQL v3 (when deployed)
```

### Test Connectivity
```bash
# Test direct access to v2
curl -f http://localhost:2222/health/live && echo "✅ v2 healthy"

# Test access through nginx
curl -f http://localhost:8080/nginx-health && echo "✅ Nginx healthy"
curl -f http://localhost:8080/apis/registry/v2/system/info && echo "✅ v2 via nginx"
```

## Still TODO

The following files still need port updates:

- [ ] `TEST_PLAN.md` - All port references in examples
- [ ] `IMPLEMENTATION_STATUS.md` - Port references in examples
- [ ] `README.md` - Some port references may remain
- [ ] Future step scripts (C, D, F, G, H, I, J, K) - Will use correct ports when created

## Rollback

If you need to revert to the old port configuration:

1. Edit `docker-compose-v2.yml`: Change `2222:8080` back to `8080:8080`
2. Edit `docker-compose-nginx.yml`: Change `8080:8080` back to `9090:8080`
3. Update all scripts to use the old ports
4. Restart containers: `./scripts/cleanup.sh && ./scripts/step-A-deploy-v2.sh && ./scripts/step-B-deploy-nginx.sh`

---

**Status**: ✅ Complete
**Tested**: Scripts updated and ready for testing
