module simple_variables_decls_ass;


int x = 1+2*2/1-6;

discard "TDOO: Technically also not allowed (not compile-time constant in C)";
int y = 2+x;

discard "TODO: Technically the below should not be allowed as we cannot do it in C - sadly";
y = 5+5;
