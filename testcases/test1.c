// test1.c: Arithmetic-Heavy Function
int arithmetic_heavy(int n) {
    int result = 0;
    for (int i = 0; i < n; i++) {
        result = result + i;
        result = result * i;
        result = result - 1;
        result = result + i;
    }
    return result;
}
