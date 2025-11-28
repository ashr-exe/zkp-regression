#!/bin/bash
set -e  # Stop script immediately on error

echo "🚀 Starting ZK-Regression V2 Pipeline..."

# --- 0. Cleanup & Setup ---
echo "🧹 Cleaning up old artifacts..."
rm -rf build outputs
mkdir -p build
mkdir -p outputs

# --- 1. Data Pipeline ---
echo "🐍 Generating Data & Training Model..."
# Use the python inside the virtual env explicitly
./venv/bin/python3 prepare_input.py

echo "#️⃣  Adding Hash Commitment..."
node add_hash.js

# --- 2. Compilation ---
echo "🔨 Compiling Circuit..."
# We output directly to build/ to keep root clean
circom regression.circom --r1cs --wasm --sym --c --output build

# --- 3. Trusted Setup (Groth16) ---
echo "🔐 Running Trusted Setup..."
# Generate randomness
snarkjs powersoftau new bn128 12 build/pot12_0000.ptau -v
snarkjs powersoftau contribute build/pot12_0000.ptau build/pot12_final.ptau --name="V2Auto" -v -e="random_entropy"
# Prepare Phase 2 (Crucial step you missed in your list but needed!)
snarkjs powersoftau prepare phase2 build/pot12_final.ptau build/pot12_prepared.ptau -v

# Generate Keys
snarkjs groth16 setup build/regression.r1cs build/pot12_prepared.ptau build/regression_0000.zkey
snarkjs zkey contribute build/regression_0000.zkey build/regression_final.zkey --name="V2Keys" -v -e="more_randomness"
snarkjs zkey export verificationkey build/regression_final.zkey build/verification_key.json

# --- 4. Prove & Verify ---
echo "📝 Generating Proof..."
# Calculate Witness
node build/regression_js/generate_witness.js build/regression_js/regression.wasm input.json outputs/witness.wtns

# Generate Proof
snarkjs groth16 prove build/regression_final.zkey outputs/witness.wtns outputs/proof.json outputs/public.json

# Verify
echo "⚖️  Verifying Proof..."
snarkjs groth16 verify build/verification_key.json outputs/public.json outputs/proof.json

# --- 5. Picus Safety Check ---
echo "🦆 Running Picus Safety Check..."
# We save our current location so we can come back
PROJECT_DIR=$(pwd)

# Go to picus, run check pointing back to our build folder
cd ~/picus
racket picus-dpvl-uniqueness.rkt --r1cs "$PROJECT_DIR/build/regression.r1cs" --timeout 20000

# Go back to project dir
cd "$PROJECT_DIR"

echo "✅ Pipeline Complete!"