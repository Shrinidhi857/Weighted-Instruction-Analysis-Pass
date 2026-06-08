// test2.c: Memory and Call-Heavy Function
int helper_function(int x) {
    return (x * 2) + x;
}

int memory_and_call_heavy(int *arr, int size) {
    int result = 0;
    for (int i = 0; i < size; i++) {
        int temp = arr[i];
        temp = helper_function(temp);
        result = result + temp;
        arr[i] = temp;
    }
    return result;
}
