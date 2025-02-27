typedef int int2 __attribute__((__ext_vector_type__(2)));

void foo() {
  int2 v0;
  int v1[2];
  vload(v1[0], &v0);
  v0 += v0;
  vstore(v0, v1[0]);
}
