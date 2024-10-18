module multi_module_cycle_1;

import multi_module_cycle_2;

struct A
{
    multi_module_cycle_2.B x;
}

