pragma circom 2.0.0;
include "node_modules/circomlib/circuits/comparators.circom";
include "node_modules/circomlib/circuits/poseidon.circom";

template RegressionVerifierV2(n) {
    // --- Inputs ---
    signal input x[n];
    signal input y[n];
    signal input m; 
    signal input c;
    signal input threshold; 

    // NEW: Public Commitment (The Fingerprint)
    // This is the hash of the dataset that everyone agreed on beforehand.
    signal input data_commitment; 

    // --- 1. Data Integrity Check (Hashing) ---
    // We use Poseidon to hash the X array and Y array
    component hash_x = Poseidon(n);
    component hash_y = Poseidon(n);

    for (var i = 0; i < n; i++) {
        hash_x.inputs[i] <== x[i];
        hash_y.inputs[i] <== y[i];
    }

    // Hash the two results together to get one final ID
    component final_hash = Poseidon(2);
    final_hash.inputs[0] <== hash_x.out;
    final_hash.inputs[1] <== hash_y.out;

    // CONSTRAINT: The data provided MUST match the public commitment
    final_hash.out === data_commitment;

    // --- 2. Model Accuracy Check (Same as V1) ---
    signal diff[n];
    signal sq_err[n];
    var sum = 0;

    for (var i = 0; i < n; i++) {
        var pred = m * x[i] + c;
        diff[i] <== y[i] - pred;
        sq_err[i] <== diff[i] * diff[i];
        sum += sq_err[i];
    }

    signal total_error;
    total_error <== sum;

    component lt = LessThan(64);
    lt.in[0] <== total_error;
    lt.in[1] <== threshold;
    lt.out === 1;
}

// We make 'data_commitment' public so the Verifier knows WHICH data we used.
component main {public [threshold, data_commitment]} = RegressionVerifierV2(10);