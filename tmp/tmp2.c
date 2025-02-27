void foo() {
  int src[2];
  int dst[2];
  int tag[1];
  dma_start(src[0], dst[0], tag[0], 2);
  dma_wait(tag[0], 2);
}
