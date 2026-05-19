require("dotenv/config");
const { Client } = require("pg");

async function main() {
  const dbUrl = process.env.DATABASE_URL;

  if (!dbUrl) {
    console.error("DATABASE_URL missing in .env");
    process.exit(1);
  }

  const url = new URL(dbUrl);
  const targetDb = url.pathname.replace("/", "");

  if (!targetDb) {
    console.error("Database name missing in DATABASE_URL");
    process.exit(1);
  }

  if (!/^[a-zA-Z0-9_]+$/.test(targetDb)) {
    console.error("Unsafe database name:", targetDb);
    process.exit(1);
  }

  const adminUrl = new URL(dbUrl);
  adminUrl.pathname = "/postgres";

  const client = new Client({
    connectionString: adminUrl.toString(),
  });

  await client.connect();

  const exists = await client.query(
    "SELECT 1 FROM pg_database WHERE datname = $1",
    [targetDb]
  );

  if (exists.rowCount > 0) {
    console.log(`Database "${targetDb}" already exists.`);
  } else {
    await client.query(`CREATE DATABASE "${targetDb}"`);
    console.log(`Database "${targetDb}" created successfully.`);
  }

  await client.end();
}

main().catch((error) => {
  console.error("Database create failed:");
  console.error(error.message);
  process.exit(1);
});
