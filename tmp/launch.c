__kernel void foo(__global float *input) {}

void launch(const char *, int, int, char **);

void main() {
    char *inputs[1];
    inputs[0] = malloc(10);
    launch("foo", 1, 1, (char **)inputs);
    free(inputs[0]);
}
