use rusqlite::{params, Connection, Result};

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn open(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS whitelist (
                address TEXT PRIMARY KEY,
                added_at_nonce INTEGER
            )",
            [],
        )?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS sync_state (
                key TEXT PRIMARY KEY,
                value TEXT
            )",
            [],
        )?;
        Ok(Database { conn })
    }

    pub fn add_address(&self, address: &str, nonce: u64) -> Result<()> {
        self.conn.execute(
            "INSERT OR REPLACE INTO whitelist (address, added_at_nonce) VALUES (?1, ?2)",
            params![address, nonce],
        )?;
        Ok(())
    }

    pub fn remove_address(&self, address: &str) -> Result<()> {
        self.conn.execute(
            "DELETE FROM whitelist WHERE address = ?1",
            params![address],
        )?;
        Ok(())
    }

    pub fn get_all_addresses(&self) -> Result<Vec<String>> {
        let mut stmt = self.conn.prepare("SELECT address FROM whitelist")?;
        let rows = stmt.query_map([], |row| row.get(0))?;
        let mut addresses = Vec::new();
        for row in rows {
            addresses.push(row?);
        }
        Ok(addresses)
    }

    pub fn set_sync_state(&self, key: &str, value: &str) -> Result<()> {
        self.conn.execute(
            "INSERT OR REPLACE INTO sync_state (key, value) VALUES (?1, ?2)",
            params![key, value],
        )?;
        Ok(())
    }

    pub fn get_sync_state(&self, key: &str) -> Result<Option<String>> {
        let mut stmt = self.conn.prepare("SELECT value FROM sync_state WHERE key = ?1")?;
        let mut rows = stmt.query(params![key])?;
        if let Some(row) = rows.next()? {
            Ok(Some(row.get(0)?))
        } else {
            Ok(None)
        }
    }
}
