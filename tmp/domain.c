//typedef void cpu1_func __attribute__((annotate("cpu1")));
//cpu1_func dev_dma(float* a, float* b);

__attribute__((annotate("cpu1"))) void myFunction(float* a, float* b);

int get_global_id(int);

__kernel void GEMM(const int M, const int N, const int K,
                   const __global float* A,
                   const __global float* B,
                   __global float* C);

