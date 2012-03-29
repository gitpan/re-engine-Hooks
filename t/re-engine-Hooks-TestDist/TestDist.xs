/* This file is part of the re::engine::Hooks Perl module.
 * See http://search.cpan.org/dist/re-engine-Hooks/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "re_engine_hooks.h"

#define __PACKAGE__     "re::engine::Hooks::TestDist"
#define __PACKAGE_LEN__ (sizeof(__PACKAGE__)-1)

#include "regcomp.h"

STATIC SV *reht_foo_var;

#define REHT_PUSH_NODE_NAME(V, P) do { \
 if (V) {                              \
  SV *sv = newSVpvn(P, sizeof(P) - 1); \
  sv_catpv(sv, PL_reg_name[OP(node)]); \
  av_push((AV *) SvRV(V), sv);         \
 } } while (0)

STATIC void reht_foo_comp(pTHX_ regexp *rx, regnode *node) {
 REHT_PUSH_NODE_NAME(reht_foo_var, "c:");
}

STATIC void reht_foo_exec(pTHX_ regexp *rx, regnode *node, regmatch_info *reginfo, regmatch_state *st) {
 REHT_PUSH_NODE_NAME(reht_foo_var, "e:");
}

STATIC SV *reht_bar_var;

STATIC void reht_bar_comp(pTHX_ regexp *rx, regnode *node) {
 REHT_PUSH_NODE_NAME(reht_bar_var, "c:");
}

STATIC void reht_bar_exec(pTHX_ regexp *rx, regnode *node, regmatch_info *reginfo, regmatch_state *st) {
 REHT_PUSH_NODE_NAME(reht_bar_var, "e:");
}

STATIC SV *reht_custom_var;

STATIC void reht_custom_comp(pTHX_ regexp *rx, regnode *node) {
 const char *node_name;

 node_name = PL_reg_name[OP(node)];
}

STATIC void reht_custom_exec(pTHX_ regexp *rx, regnode *node, regmatch_info *reginfo, regmatch_state *st) {
 STRLEN      node_namelen;
 const char *node_name;

 node_name    = PL_reg_name[OP(node)];
 node_namelen = strlen(node_name);

 dSP;

 ENTER;
 SAVETMPS;

 PUSHMARK(SP);
 EXTEND(SP, 1);
 mPUSHp(node_name, node_namelen);
 PUTBACK;

 call_sv(reht_custom_var, G_VOID | G_EVAL);

 FREETMPS;
 LEAVE;
}

/* --- XS ------------------------------------------------------------------ */

MODULE = re::engine::Hooks::TestDist    PACKAGE = re::engine::Hooks::TestDist

PROTOTYPES: ENABLE

BOOT:
{
 reh_register(__PACKAGE__ "::foo", reht_foo_comp, reht_foo_exec);
 reht_foo_var = NULL;

 reh_register(__PACKAGE__ "::bar", reht_bar_comp, reht_bar_exec);
 reht_bar_var = NULL;

 reh_register(__PACKAGE__ "::custom", reht_custom_comp, reht_custom_exec);
 reht_custom_var = NULL;
}

void
set_variable(SV *key, SV *var)
PROTOTYPE: $$
PREINIT:
 STRLEN      len;
 const char *s;
PPCODE:
 s = SvPV(key, len);
 if (len == 3 && strcmp(s, "foo") == 0) {
  if (!SvROK(var) || SvTYPE(SvRV(var)) != SVt_PVAV)
   croak("Invalid variable type");
  SvREFCNT_dec(reht_foo_var);
  reht_foo_var = SvREFCNT_inc(var);
 } else if (len == 3 && strcmp(s, "bar") == 0) {
  if (!SvROK(var) || SvTYPE(SvRV(var)) != SVt_PVAV)
   croak("Invalid variable type");
  SvREFCNT_dec(reht_bar_var);
  reht_bar_var = SvREFCNT_inc(var);
 } else if (len == 6 && strcmp(s, "custom") == 0) {
  SvREFCNT_dec(reht_custom_var);
  reht_custom_var = SvREFCNT_inc(var);
 }
 XSRETURN(0);
