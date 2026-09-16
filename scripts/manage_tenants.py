#!/usr/bin/env python3
import sqlite3
import uuid
import secrets
import hashlib
import json
import sys
from datetime import datetime, timezone

DB_PATH = "/home/gavadala/.omniroute/storage.sqlite"

def get_db():
    return sqlite3.connect(DB_PATH)

def create_tenant_key(name: str, plan: str = "starter-20eur", monthly_usd: float = 20.0, monthly_tokens: int = 5000000):
    con = get_db()
    cur = con.cursor()
    
    key_id = str(uuid.uuid4())
    random_hex = secrets.token_hex(16)
    raw_key = f"sk-omni-{random_hex}"
    key_prefix = raw_key[:12]
    key_hash = hashlib.sha256(raw_key.encode()).hexdigest()
    now_iso = datetime.now(timezone.utc).isoformat()
    
    daily_usd = round((monthly_usd / 30.0) * 1.15, 2)
    weekly_usd = round((monthly_usd / 4.0) * 1.15, 2)
    
    cur.execute("""
        INSERT INTO api_keys (
            id, name, key, machine_id, allowed_models, no_log,
            created_at, revoked_at, expires_at, last_used_at, key_prefix,
            scopes, allowed_combos, stream_default_mode, allowed_quotas,
            disable_non_public_models, usage_limit_enabled, daily_usage_limit_usd,
            weekly_usage_limit_usd, cache_default_mode, model_access_mode,
            compression_enabled, is_active, max_requests_per_minute, max_requests_per_day,
            key_hash
        ) VALUES (
            ?, ?, ?, ?, ?, ?,
            ?, NULL, NULL, NULL, ?,
            ?, ?, 'legacy', '[]',
            0, 1, ?,
            ?, 'legacy', 'all',
            1, 1, 60, 2000,
            ?
        )
    """, (
        key_id, f"{name} ({plan})", raw_key, secrets.token_hex(8), "[]", 0,
        now_iso, key_prefix,
        json.dumps(["self:usage"]), json.dumps(["combo/*"]),
        daily_usd, weekly_usd, key_hash
    ))
    
    # Add token limit rule (Monthly reset)
    limit_id = str(uuid.uuid4())
    cur.execute("""
        INSERT INTO api_key_token_limits (
            id, api_key_id, scope_type, scope_value, token_limit,
            reset_interval, reset_time, enabled, created_at, updated_at
        ) VALUES (
            ?, ?, 'global', '*', ?,
            'monthly', NULL, 1, ?, ?
        )
    """, (limit_id, key_id, monthly_tokens, now_iso, now_iso))
    
    con.commit()
    con.close()
    
    print("==================================================")
    print("✓ Tenant Key Created Successfully!")
    print(f"  Tenant Name:    {name}")
    print(f"  Plan:           {plan} (20 EUR/mese)")
    print(f"  Virtual API Key:{raw_key}")
    print(f"  Monthly Cap:    ${monthly_usd:.2f} USD (~{monthly_tokens:,} tokens)")
    print(f"  Rate Limit:     60 req/min | 2,000 req/day")
    print(f"  Compression:    Enabled (RTK / Smart Deduplication)")
    print("==================================================")
    return raw_key

def list_tenants():
    con = get_db()
    cur = con.cursor()
    cur.execute("""
        SELECT k.id, k.name, k.key_prefix, k.is_active, k.daily_usage_limit_usd, 
               k.weekly_usage_limit_usd, l.token_limit, k.last_used_at, k.created_at
        FROM api_keys k
        LEFT JOIN api_key_token_limits l ON k.id = l.api_key_id
        ORDER BY k.created_at DESC
    """)
    rows = cur.fetchall()
    con.close()
    
    print(f"{'NAME':<40} {'KEY PREFIX':<15} {'ACTIVE':<8} {'DAILY USD':<10} {'TOKENS/M':<12} {'LAST USED':<22}")
    print("-" * 110)
    for r in rows:
        name = r[1] or "Unnamed"
        prefix = r[2] or ""
        active = "YES" if r[3] else "NO"
        daily = f"${r[4]:.2f}" if r[4] else "None"
        tokens = f"{r[6]:,}" if r[6] else "Unlimited"
        used = (r[7] or "Never")[:19]
        print(f"{name:<40} {prefix:<15} {active:<8} {daily:<10} {tokens:<12} {used:<22}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "create":
        tenant_name = sys.argv[2] if len(sys.argv) > 2 else "Demo Client"
        create_tenant_key(tenant_name)
    else:
        list_tenants()
