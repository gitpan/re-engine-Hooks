EXTERN_C void reh_call_comp_hook(pTHX_ regexp *, regnode *);
EXTERN_C void reh_call_exec_hook(pTHX_ regexp *, regnode *, regmatch_info *, regmatch_state *);

#define REH_CALL_REGCOMP_HOOK(a, b)       reh_call_comp_hook(aTHX_ (a), (b))
#define REH_CALL_REGEXEC_HOOK(a, b, c, d) reh_call_exec_hook(aTHX_ (a), (b), (c), (d))

