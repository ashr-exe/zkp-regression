pragma circom 2.0.0;
include "node_modules/circomlib/circuits/comparators.circom";

template RegressionVerifier(n) {
    // --- Private Inputs ---
    signal input x[n];
    signal input y[n];
    signal input m; 
    signal input c;

    // --- Public Input ---
    signal input threshold; 

    // --- Internal Logic ---
    signal diff[n];
    signal sq_err[n];
    var sum = 0;

    for (var i = 0; i < n; i++) {
        // 1. Predict: y = mx + c
        var pred = m * x[i] + c;
        
        // 2. Diff: y_real - y_pred
        diff[i] <== y[i] - pred;

        // 3. Square Error
        sq_err[i] <== diff[i] * diff[i];

        // 4. Accumulate
        sum += sq_err[i];
    }

    // Convert var to signal for constraint
    signal total_error;
    total_error <== sum;

    // Check: total_error < threshold
    component lt = LessThan(64);
    lt.in[0] <== total_error;
    lt.in[1] <== threshold;
    lt.out === 1;
}

// We fix n=10 because our Python script used 10 points
component main {public [threshold]} = RegressionVerifier(10);