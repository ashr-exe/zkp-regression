# ZK-Linear-Regression: Zero-Knowledge Proof of Accuracy

> **Goal:** Prove that a hidden Linear Regression model ($y = mx + c$) fits a private dataset with a specific accuracy (SSE), without revealing the model parameters or the data itself.

This project is a **Zero-Knowledge Machine Learning (ZKML)** implementation using **Circom** and **SnarkJS**. It bridges the gap between traditional data science (Scikit-Learn) and cryptographic circuits (Finite Fields).

Demo Video: https://drive.google.com/file/d/1_HjC2_fuXmcxw3ZfNAa0Gjnjy89ajsU5/view?usp=drive_link

---
# V2: Data Commitments

> **Goal:** Prove model accuracy while cryptographically binding the proof to a specific, immutable dataset hash.

This V2 implementation improves upon the V1 base by adding **Data Integrity Checks**.
In V1, a prover could potentially swap the dataset for a fake one that fits the model.
In V2, we enforce a **Poseidon Hash Commitment**.

## 🔒 Security Architecture

### The Commitment Scheme
1.  **Off-Chain:** We calculate `Hash(Dataset)` using the Poseidon hash function.
2.  **Public Input:** This hash is pinned as a public input (`data_commitment`).
3.  **In-Circuit:**
    * The circuit takes the private dataset ($x, y$).
    * It re-calculates the Poseidon hash inside the circuit.
    * It enforces `Calculated_Hash === Public_Commitment`.

If the Prover tries to change even a single data point to cheat the accuracy score, the hashes will mismatch and the proof will fail.

## 🛠️ Tech Stack
* **Circom:** Circuit logic.
* **CircomLib:** Standard library (Comparators).
* **CircomLibJS:** For off-chain Poseidon hashing (in `add_hash.js`).
* **Picus:** Formally verified as **Safe**.

## 🚀 How to Run (Hybrid Pipeline)

**1. Data Pipeline (Python -> JS)**
```bash
# Generate Data & Train Model
python3 prepare_input.py

# Calculate Commitment & Format JSON
node add_hash.js
```

---

## 🧠 V1 Engineering The Solution: The Journey

Building this circuit required solving three fundamental mismatches between Standard Math and ZK Math.

### 1. The Floating Point Problem (Quantization)
**The Conflict:** Linear Regression relies on decimals (e.g., slope $m = 2.35$). ZK Circuits only understand integers.
**The Solution:** We treat the circuit like a fixed-point calculator.
* We scale all inputs (Dataset $x, y$ and Model $m, c$) by a factor of **1,000**.
* $2.35 \rightarrow 2350$.
* The circuit performs integer arithmetic. The Verifier understands that the result is effectively "scaled."

### 2. The "Grid Snapping" Problem (Thresholds)
**The Conflict:** Why check `Error < Threshold` instead of `Error == Expected`?
**The Insight:**
* **Python** calculates using 64-bit Floats (High Precision).
* **Circom** calculates using Truncated Integers (Low Precision / "Dumb Math").
* Even if the model is perfect in Python, the "Grid Snapping" (rounding errors) in the circuit will produce a slightly different result.
* **Implementation:** We calculate the exact "Dumb Math" SSE in Python first, add a **5% safety buffer**, and set that as the public threshold.

### 3. The "Wrap Around" Problem (Squaring)
**The Conflict:** In Finite Fields, negative numbers don't exist; they wrap around to massive numbers (e.g., $-2 \equiv 21888...$).
**The Solution:** We calculate the **Sum of Squared Errors (SSE)**.
* Calculating `diff = y - pred` might result in a massive wrapped number.
* However, squaring that wrapped number $(y - pred)^2$ mathematically returns the result to the correct small, positive magnitude. This allows us to verify distance without dealing with modular arithmetic headaches.

---

## 🛠 Architecture

### The Circuit Logic (`regression.circom`)
We implement a **Forward Pass** verification:
1.  **Inputs:** Private Data ($x, y$), Private Model ($m, c$), Public Threshold.
2.  **Prediction:** $\hat{y} = m \cdot x + c$.
3.  **Accumulation:** $\sum (y_{real} - \hat{y})^2$.
4.  **Check:** The circuit enforces `Total_SSE < Threshold` using a binary comparator.

---

## 🔒 Security Audit (Picus)

This circuit was audited using **Picus**, a static analyzer for ZK circuits that formally verifies uniqueness.

**Audit Result:** `Strong Uniqueness: Safe`  
*This certifies that the circuit is properly constrained and contains no under-constrained signals that could be exploited by a malicious prover.*

### Reproducing the Audit
Picus requires a specific Racket/Rosette environment.

1.  **Install Racket & Dependencies:**
    ```bash
    sudo apt install -y racket
    raco pkg install --auto rosette csv-reading graph-lib math-lib
    ```

2.  **Clone Picus:**
    ```bash
    git clone [https://github.com/chyanju/picus.git](https://github.com/chyanju/picus.git)
    cd picus
    ./scripts/prepare-circomlib.sh
    ```

3.  **Run the Analyzer:**
    ```bash
    # Point it to the compiled r1cs file
    racket picus-dpvl-uniqueness.rkt --r1cs ../zkp-regression/build/regression.r1cs
    ```

---

## 🚀 Quick Start

### 1. Prerequisites
* **Node.js** (v20+)
* **Python 3.10+** (with `numpy` and `scikit-learn`)
* **Rust** (for Circom)

### 2. Installation
```bash
# Install JS dependencies
npm install

# Install Python dependencies
# (Use a virtual env or --break-system-packages on WSL)
pip install numpy scikit-learn
````

### 3\. The Workflow

**Step A: Generate Data & Train Model (Python)**
This script uses random data, trains a Scikit-Learn model, performs the quantization, and calculates the required threshold.

```bash
python3 prepare_input.py
```

*Check `input.json` to see the scaled integer inputs.*

**Step B: Compile the Circuit**

```bash
circom regression.circom --r1cs --wasm --sym --c
```

**Step C: Trusted Setup (Groth16)**
Generate the cryptographic keys.

```bash
# 1. Powers of Tau (Phase 1)
snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First" -v -e="random"
snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v

# 2. Circuit Setup (Phase 2)
snarkjs groth16 setup build/regression.r1cs pot12_final.ptau build/regression_0000.zkey
snarkjs zkey contribute build/regression_0000.zkey build/regression_final.zkey --name="Second" -v -e="random"
snarkjs zkey export verificationkey build/regression_final.zkey build/verification_key.json
```

**Step D: Prove & Verify**

```bash
# 1. Calculate Witness (The Computation)
node build/regression_js/generate_witness.js build/regression_js/regression.wasm input.json outputs/witness.wtns

# 2. Generate Proof (The Cryptography)
snarkjs groth16 prove build/regression_final.zkey outputs/witness.wtns outputs/proof.json outputs/public.json

# 3. Verify (The Check)
snarkjs groth16 verify build/verification_key.json outputs/public.json outputs/proof.json
```

### Expected Output

```text
[INFO]  snarkJS: OK!
```

This confirms the hidden model fits the hidden data within the specified error threshold.

-----

## 📂 Repository Structure

  * `regression.circom`: The ZK Circuit logic.
  * `prepare_input.py`: The "Brain" (Training, Quantization, Threshold logic).
  * `input.json`: The generated inputs (ignored in production, visible here for demo).
  * `build/`: Compiled artifacts (`.r1cs`, `.wasm`, `.zkey`).
  * `outputs/`: Execution results (`proof.json`, `witness.wtns`).

-----

*Version 1.0*
