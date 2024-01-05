#include <neorv32.h>
#include <oup.h>
#include <oup_wishbone.h>

int main() {
    while(1) {
        oup_wishbone_resetphy();
        neorv32_cpu_delay_ms(250);
    }
    return 0;
}