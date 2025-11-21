import json
import numpy as np
from sklearn.linear_model import LinearRegression

# --- Configuration ---
SCALE = 1000
N_POINTS = 10 

# --- 1. Hardcoded Data (The "Real World" Evidence) ---
# Trend: Roughly y = 4x + 5, but with manual noise added
# X must be integers (for V1 simplicity)
x_raw = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
# Y is float data
y_raw = [9.2, 12.8, 17.1, 21.5, 24.8, 29.1, 32.7, 37.2, 41.0, 45.3]

# Reshape X for Sklearn (needs a column vector)
X_data = np.array(x_raw).reshape(-1, 1)
y_data = np.array(y_raw)

print("--- 1. Raw Data ---")
print(f"X: {x_raw}")
print(f"Y: {y_raw}")

# --- 2. Train the Model ---
model = LinearRegression()
model.fit(X_data, y_data)

m_float = model.coef_[0]
c_float = model.intercept_

print(f"\n--- 2. Python Model ---")
print(f"Best fit found: y = {m_float:.4f}x + {c_float:.4f}")
# (We expect m approx 4.0 and c approx 5.0)

# --- 3. Quantization (The "Dumb" Inputs) ---
# Truncate to Integers. This is what enters the circuit.
m_int = int(m_float * SCALE)
c_int = int(c_float * SCALE)

# Prepare Data Inputs (Scale Y, keep X as is)
x_ints = x_raw
y_ints = [int(y * SCALE) for y in y_raw]

print(f"\n--- 3. Circuit Inputs (Scaled {SCALE}x) ---")
print(f"m: {m_int}")
print(f"c: {c_int}")

# --- 4. Circuit Simulation (Calculating the Threshold) ---
# We MUST do the math exactly as the circuit does (Integer math)
circuit_sse = 0

print("\n--- 4. Simulating Circuit Execution ---")
print("Point | Real Y (Sc) | Pred Y (Sc) | Diff | Sq Error")

for i in range(N_POINTS):
    # Circuit Logic: y = mx + c
    # m_int and c_int are already scaled. x is 1.
    # Result units: 1000 * 1 = 1000. Matches Y units.
    pred = (m_int * x_ints[i]) + c_int
    
    # Diff
    real_y = y_ints[i]
    diff = real_y - pred
    
    # Square
    sq_err = diff * diff
    
    # Accumulate
    circuit_sse += sq_err
    
    print(f" {i+1:2d}   |   {real_y:5d}     |   {pred:5d}     | {diff:3d}  | {sq_err}")

print(f"\nTotal Circuit SSE: {circuit_sse} (unscaled: {circuit_sse / (SCALE * SCALE)})")

# --- 5. Set Threshold ---
# Add 5% Buffer
buffer = int(circuit_sse * 0.05)
threshold = circuit_sse + buffer

print(f"Threshold: {threshold} (SSE + 5%)")

# --- 6. Output JSON ---
data = {
    "x": [str(x) for x in x_ints],
    "y": [str(y) for y in y_ints],
    "m": str(m_int),
    "c": str(c_int),
    "threshold": str(threshold)
}

with open("input.json", "w") as f:
    json.dump(data, f, indent=2)

print("\nSuccess! input.json ready.")