import asyncio
import sys

async def reset_db():
    try:
        import asyncpg
        print("Using asyncpg...")
        # Connect to default postgres db
        conn = await asyncpg.connect('postgresql://postgres:1122@localhost:5432/postgres')
        print("Connected to postgres database")
        
        # Terminate active connections to PayTalk_dbss
        await conn.execute("""
            SELECT pg_terminate_backend(pg_stat_activity.pid)
            FROM pg_stat_activity
            WHERE pg_stat_activity.datname = 'PayTalk_dbss'
            AND pid <> pg_backend_pid();
        """)
        
        await conn.execute("DROP DATABASE IF EXISTS \"PayTalk_dbss\";")
        print("Dropped PayTalk_dbss")
        
        await conn.execute("CREATE DATABASE \"PayTalk_dbss\";")
        print("Created PayTalk_dbss")
        
        await conn.close()
        return
    except ImportError:
        pass

    try:
        import psycopg2
        from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
        print("Using psycopg2...")
        conn = psycopg2.connect('postgresql://postgres:1122@localhost:5432/postgres')
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()
        print("Connected to postgres database")
        
        cur.execute("""
            SELECT pg_terminate_backend(pg_stat_activity.pid)
            FROM pg_stat_activity
            WHERE pg_stat_activity.datname = 'PayTalk_dbss'
            AND pid <> pg_backend_pid();
        """)
        
        cur.execute('DROP DATABASE IF EXISTS "PayTalk_dbss";')
        print("Dropped PayTalk_dbss")
        
        cur.execute('CREATE DATABASE "PayTalk_dbss";')
        print("Created PayTalk_dbss")
        
        cur.close()
        conn.close()
        return
    except ImportError:
        pass
        
    print("Neither asyncpg nor psycopg2 found. Cannot reset database.")
    sys.exit(1)

if __name__ == '__main__':
    asyncio.run(reset_db())
