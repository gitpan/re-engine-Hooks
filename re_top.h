#define Perl_regexec_flags            reh_regexec
#define Perl_regdump                  reh_regdump
#define Perl_regprop                  reh_regprop
#define Perl_re_intuit_start          reh_re_intuit_start
#define Perl_re_compile               reh_regcomp
#define Perl_regfree_internal         reh_regfree
#define Perl_re_intuit_string         reh_re_intuit_string
#define Perl_regdupe_internal         reh_regdupe
#define Perl_reg_numbered_buff_fetch  reh_reg_numbered_buff_fetch
#define Perl_reg_numbered_buff_store  reh_reg_numbered_buff_store
#define Perl_reg_numbered_buff_length reh_reg_numbered_buff_length
#define Perl_reg_named_buff           reh_reg_named_buff
#define Perl_reg_named_buff_iter      reh_reg_named_buff_iter
#define Perl_reg_named_buff_fetch     reh_reg_named_buff_fetch    
#define Perl_reg_named_buff_exists    reh_reg_named_buff_exists  
#define Perl_reg_named_buff_firstkey  reh_reg_named_buff_firstkey
#define Perl_reg_named_buff_nextkey   reh_reg_named_buff_nextkey 
#define Perl_reg_named_buff_scalar    reh_reg_named_buff_scalar  
#define Perl_reg_named_buff_all       reh_reg_named_buff_all     
#define Perl_reg_qr_package           reh_reg_qr_package

/* Do not enable debugging stuff from perl.h */

#undef PERL_EXT_RE_BUILD
