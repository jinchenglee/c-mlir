__attribute__((annotate("cpu1"))) int get_event_id(int);

//__cpu1 void GEMM(const int M, const int N, const int K,
__attribute__((annotate("cpu1"))) __kernel void GEMM(const int M, const int N, const int K,
                   const __global float* A,
                   const __global float* B,
                   __global float* C) {
    
    // Thread identifiers
    const int event0 = get_event_id(0);
    const int event1 = get_event_id(1);
 

    // Iterate through rows of A
    for (int i = 0; i < M; i++) {
        // Iterate through columns of B
        for (int j = 0; j < N; j++) {
            // Initialize the current element of C
            C[i * N + j] = 0.0f;
            
            // Dot product of row i of A with column j of B
            for (int k = 0; k < K; k++) {
                // A[i, k] * B[k, j]
                C[i * N + j] += A[i * K + k] * B[k * N + j];
            }
        }
    }
}
