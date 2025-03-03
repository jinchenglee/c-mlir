
#define VERSION 5

#define DOMAIN(text) __attribute__((annotate(text)))

int get_event_id(int);

__attribute__((annotate("cpu2"))) extern void cpu2_dma(const __global float* A_src, __global float* A, int size);

DOMAIN("cpu1") void cpu1_dma(const __global float* A_src, __global float* A, int size) {
  // mem copy from A_src to A
}


void gemm(const int M, const int N, const int K,
                   const __global float* A,
                   const __global float* B,
                   __global float* C) {
    
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            C[i * N + j] = 0.0f;
            
            for (int k = 0; k < K; k++) {
                C[i * N + j] += A[i * K + k] * B[k * N + j];
            }
        }
    }
}

void procedure(
      __global float* A,
      const __global float* A_src,
      const __global float* B,
      __global float* C_dst,
      const __global float* C)
{
    // Thread identifiers
    const int event0 = get_event_id(0);
    const int event1 = get_event_id(1);

    const int M = 10;
    const int N = 6;
    const int K = 8;

    cpu1_dma(A_src, A, M*K);
    gemm(M, N, K, A, B, C);
    cpu1_dma(C, C_dst, M*N);
}
