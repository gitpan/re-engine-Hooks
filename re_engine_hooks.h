/* This file is part of the re::engine::Hooks Perl module.
 * See http://search.cpan.org/dist/re-engine-Hooks/ */

#ifndef RE_ENGINE_HOOKS_H
#define RE_ENGINE_HOOKS_H 1

typedef void (*reh_comp_hook)(pTHX_ regexp *, regnode *);
typedef void (*reh_exec_hook)(pTHX_ regexp *, regnode *, regmatch_info *, regmatch_state *);

void reh_register(pTHX_ const char *key, reh_comp_hook comp, reh_exec_hook exec);
#define reh_register(K, C, E) reh_register(aTHX_ (K), (C), (E))

#endif /* RE_ENGINE_HOOKS_H */

