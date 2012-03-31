EXTERN_C void reh_call_comp_begin_hook(pTHX_ regexp *);
EXTERN_C void reh_call_comp_hook(pTHX_ regexp *, regnode *);
EXTERN_C void reh_call_exec_hook(pTHX_ regexp *, regnode *, regmatch_info *, regmatch_state *);

#define REH_CALL_COMP_BEGIN_HOOK(a)         reh_call_comp_begin_hook(aTHX_ (a))
#define REH_CALL_COMP_NODE_HOOK(a, b)       reh_call_comp_node_hook(aTHX_ (a), (b))
#define REH_CALL_EXEC_NODE_HOOK(a, b, c, d) reh_call_exec_node_hook(aTHX_ (a), (b), (c), (d))

