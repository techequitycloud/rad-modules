console.log("=== V8 DIAGNOSTICS & MIGRATION ===");

const fs = require('fs');
const { spawn } = require('child_process');
const { Client } = require('pg');

async function run() {
    try {
        // 1. INSPECT SOURCE CODE
        const ppPath = '/app/medusa/node_modules/@medusajs/medusa/dist/services/payment-provider.js';
        console.log(`\n--- INSPECTING ${ppPath} ---`);
        if (fs.existsSync(ppPath)) {
            const content = fs.readFileSync(ppPath, 'utf8');
            const lines = content.split('\n');
            // Line 113 (index 112)
            const targetLine = 112;
            const start = Math.max(0, targetLine - 10);
            const end = Math.min(lines.length, targetLine + 10);
            for (let i = start; i < end; i++) {
                const marker = (i === targetLine) ? '>>> ' : '    ';
                console.log(`${marker}${i + 1}: ${lines[i]}`);
            }
        } else {
            console.log("FILE NOT FOUND!");
        }

        // 2. FORCE MIGRATIONS
        console.log("\n--- RUNNING MIGRATIONS (npx medusa migrations run) ---");
        await new Promise((resolve, reject) => {
            const proc = spawn('npx', ['medusa', 'migrations', 'run'], { stdio: 'inherit' });
            proc.on('close', (code) => {
                if (code === 0) {
                    console.log("MIGRATIONS SUCCESS");
                    resolve();
                } else {
                    console.log(`MIGRATIONS FAILED with code ${code}`);
                    // Resolve anyway to check tables
                    resolve();
                }
            });
            proc.on('error', (err) => {
                console.log(`FAILED TO SPAWN MIGRATIONS: ${err.message}`);
                resolve();
            });
        });

        // 3. CHECK TABLES
        console.log("\n--- CHECKING DATABASE TABLES ---");
        const dbConfig = {
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            host: process.env.DB_HOST,
            database: process.env.DB_NAME,
            port: process.env.DB_PORT || 5432,
            ssl: false
        };
        console.log(`Connecting to ${dbConfig.host}:${dbConfig.port} / ${dbConfig.database}`);
        const client = new Client(dbConfig);
        await client.connect();
        const res = await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;");
        console.log(`Found ${res.rowCount} tables:`);
        if (res.rowCount > 0) {
            console.log(res.rows.map(r => r.table_name).join(', '));
        } else {
            console.log("NO TABLES FOUND.");
        }

        // SPECIAL CHECK FOR payment_provider
        const pp = res.rows.find(r => r.table_name === 'payment_provider');
        if (pp) console.log("VERIFIED: payment_provider table EXISTS.");
        else console.log("CRITICAL: payment_provider table MISSING.");

        await client.end();

    } catch (e) {
        console.error("CRITICAL SCRIPT ERROR:", e);
    }

    console.log("=== V8 FINISHED - EXITING ===");
}

run();
