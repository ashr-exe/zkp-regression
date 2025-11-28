const fs = require("fs");
const { buildPoseidon } = require("circomlibjs");

async function main() {
    // 1. Initialize Poseidon
    const poseidon = await buildPoseidon();
    const F = poseidon.F; // The Finite Field (BabyJubJub)

    // 2. Read the Python output
    const rawData = fs.readFileSync("temp_data.json");
    const data = JSON.parse(rawData);

    console.log("Hashing data...");

    // 3. Hash X Array
    // We map inputs to BigInt to be safe
    const xArray = data.x.map(n => BigInt(n));
    const hashX = poseidon(xArray);

    // 4. Hash Y Array
    const yArray = data.y.map(n => BigInt(n));
    const hashY = poseidon(yArray);

    // 5. Final Hash (Hash of X-hash and Y-hash)
    const finalHash = poseidon([hashX, hashY]);
    
    // Convert the hash (which is a byte array) to a number string
    const commitment = F.toObject(finalHash).toString();

    console.log("Data Commitment:", commitment);

    // 6. Create Final input.json
    const finalInput = {
        x: data.x.map(String),
        y: data.y.map(String),
        m: String(data.m),
        c: String(data.c),
        threshold: String(data.threshold),
        data_commitment: commitment
    };

    fs.writeFileSync("input.json", JSON.stringify(finalInput, null, 2));
    console.log("Success! input.json created with Commitment.");
}

main();