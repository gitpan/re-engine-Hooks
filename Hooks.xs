/* This file is part of the re::engine::Hooks Perl module.
 * See http://search.cpan.org/dist/re-engine-Hooks/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define __PACKAGE__     "re::engine::Hooks"
#define __PACKAGE_LEN__ (sizeof(__PACKAGE__)-1)

/* --- Compatibility wrappers ---------------------------------------------- */

#define REH_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#ifndef SvPV_const
# define SvPV_const(S, L) SvPV(S, L)
#endif

/* --- Lexical hints ------------------------------------------------------- */

STATIC U32 reh_hash = 0;

STATIC SV *reh_hint(pTHX) {
#define reh_hint() reh_hint(aTHX)
 SV *hint;

#ifdef cop_hints_fetch_pvn
 hint = cop_hints_fetch_pvn(PL_curcop, __PACKAGE__, __PACKAGE_LEN__,
                                       reh_hash, 0);
#elif REH_HAS_PERL(5, 9, 5)
 hint = Perl_refcounted_he_fetch(aTHX_ PL_curcop->cop_hints_hash,
                                       NULL,
                                       __PACKAGE__, __PACKAGE_LEN__,
                                       0,
                                       reh_hash);
#else
 SV **val = hv_fetch(GvHV(PL_hintgv), __PACKAGE__, __PACKAGE_LEN__, 0);
 if (!val)
  return 0;
 hint = *val;
#endif

 return hint;
}

/* --- Public API ---------------------------------------------------------- */

#include "re_engine_hooks.h"

typedef struct reh_action {
 struct reh_action *next;
 reh_comp_hook      comp;
 reh_exec_hook      exec;
 const char        *key;
 STRLEN             klen;
} reh_action;

STATIC reh_action *reh_action_list = 0;

#undef reh_register
void reh_register(pTHX_ const char *key, reh_comp_hook comp, reh_exec_hook exec) {
 reh_action *a;
 char       *key_dup;
 STRLEN      i, len;

 len = strlen(key);
 for (i = 0; i < len; ++i)
  if (!isALNUM(key[i]) && key[i] != ':')
   croak("Invalid key");
 key_dup = PerlMemShared_malloc(len + 1);
 memcpy(key_dup, key, len);
 key_dup[len] = '\0';

 a       = PerlMemShared_malloc(sizeof *a);
 a->next = reh_action_list;
 a->comp = comp;
 a->exec = exec;
 a->key  = key_dup;
 a->klen = len;

 reh_action_list = a;

 return;
}

/* --- Private API --------------------------------------------------------- */

void reh_call_comp_hook(pTHX_ regexp *rx, regnode *node) {
 SV *hint = reh_hint();

 if (hint && SvPOK(hint)) {
  STRLEN      len;
  const char *keys = SvPV_const(hint, len);
  reh_action *a;

  for (a = reh_action_list; a; a = a->next) {
   if (a->comp) {
    char *p = strstr(keys, a->key);

    if (p && (p + a->klen <= keys + len) && p[a->klen] == ' ')
     a->comp(aTHX_ rx, node);
   }
  }
 }
}

void reh_call_exec_hook(pTHX_ regexp *rx, regnode *node, regmatch_info *reginfo, regmatch_state *st) {
 SV *hint = reh_hint();

 if (hint && SvPOK(hint)) {
  STRLEN      len;
  const char *keys = SvPV_const(hint, len);
  reh_action *a;

  for (a = reh_action_list; a; a = a->next) {
   if (a->exec) {
    char *p = strstr(keys, a->key);

    if (p && (p + a->klen <= keys + len) && p[a->klen] == ' ')
     a->exec(aTHX_ rx, node, reginfo, st);
   }
  }
 }
}

/* --- Custom regexp engine ------------------------------------------------ */

#if PERL_VERSION <= 10
# define rxREGEXP(RX)  (RX)
#else
# define rxREGEXP(RX)  (SvANY(RX))
#endif

#if PERL_VERSION <= 10
EXTERN_C REGEXP *reh_regcomp(pTHX_ const SV * const, const U32);
#else
EXTERN_C REGEXP *reh_regcomp(pTHX_ SV * const, U32);
#endif
EXTERN_C I32     reh_regexec(pTHX_ REGEXP * const, char *, char *,
                                   char *, I32, SV *, void *, U32);
EXTERN_C char *  reh_re_intuit_start(pTHX_ REGEXP * const, SV *, char *,
                                           char *, U32, re_scream_pos_data *);
EXTERN_C SV *    reh_re_intuit_string(pTHX_ REGEXP * const);
EXTERN_C void    reh_regfree(pTHX_ REGEXP * const);
EXTERN_C void    reh_reg_numbered_buff_fetch(pTHX_ REGEXP * const,
                                                   const I32, SV * const);
EXTERN_C void    reh_reg_numbered_buff_store(pTHX_ REGEXP * const,
                                                   const I32, SV const * const);
EXTERN_C I32     reh_reg_numbered_buff_length(pTHX_ REGEXP * const,
                                                   const SV * const, const I32);
EXTERN_C SV *    reh_reg_named_buff(pTHX_ REGEXP * const, SV * const,
                                          SV * const, const U32);
EXTERN_C SV *    reh_reg_named_buff_iter(pTHX_ REGEXP * const,
                                               const SV * const, const U32);
EXTERN_C SV *    reh_reg_qr_package(pTHX_ REGEXP * const);
#ifdef USE_ITHREADS
EXTERN_C void *  reh_regdupe(pTHX_ REGEXP * const, CLONE_PARAMS *);
#endif

EXTERN_C const struct regexp_engine reh_regexp_engine;

REGEXP *
#if PERL_VERSION <= 10
reh_re_compile(pTHX_ const SV * const pattern, const U32 flags)
#else
reh_re_compile(pTHX_ SV * const pattern, U32 flags)
#endif
{
 struct regexp *rx;
 REGEXP        *RX;

 RX = reh_regcomp(aTHX_ pattern, flags);
 rx = rxREGEXP(RX);

 rx->engine = &reh_regexp_engine;

 return RX;
}

const struct regexp_engine reh_regexp_engine = { 
 reh_re_compile, 
 reh_regexec, 
 reh_re_intuit_start, 
 reh_re_intuit_string, 
 reh_regfree, 
 reh_reg_numbered_buff_fetch,
 reh_reg_numbered_buff_store,
 reh_reg_numbered_buff_length,
 reh_reg_named_buff,
 reh_reg_named_buff_iter,
 reh_reg_qr_package,
#if defined(USE_ITHREADS)
 reh_regdupe 
#endif
};

/* --- XS ------------------------------------------------------------------ */

MODULE = re::engine::Hooks          PACKAGE = re::engine::Hooks

PROTOTYPES: ENABLE

void
_ENGINE()
PROTOTYPE:
PPCODE:
 XPUSHs(sv_2mortal(newSViv(PTR2IV(&reh_regexp_engine))));

void
_registered(SV *key)
PROTOTYPE: $
PREINIT:
 SV         *ret = NULL;
 reh_action *a   = reh_action_list;
 STRLEN      len;
 const char *s;
PPCODE:
 s = SvPV_const(key, len);
 while (a && !ret) {
  if (a->klen == len && memcmp(a->key, s, len) == 0)
   ret = &PL_sv_yes;
  a = a->next;
 }
 if (!ret)
  ret = &PL_sv_no;
 EXTEND(SP, 1);
 PUSHs(ret);
 XSRETURN(1);
