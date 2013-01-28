#include <mruby.h>
#include <stdio.h>
#include <mruby/class.h>


mrb_value
girbind_define_module(mrb_state *mrb, mrb_value mod)
{
  mrb_value klass;
  mrb_sym sym;
  mrb_check_type(mrb, mod, MRB_TT_MODULE);
  mrb_get_args(mrb, "on", &klass,&sym);
  struct RClass *kls = mrb_class_ptr(klass);
  const char* name = mrb_sym2name(mrb,sym);
  mrb_define_module_under(mrb, kls, name);  
  return mod;
}

mrb_value
girbind_define_class(mrb_state *mrb, mrb_value mod)
{
  mrb_value klass;
  mrb_sym sym;
  mrb_value sc;
  mrb_check_type(mrb, mod, MRB_TT_MODULE);
  mrb_get_args(mrb, "ono", &klass,&sym,&sc);
  struct RClass *kls = mrb_class_ptr(klass);
  const char* name = mrb_sym2name(mrb,sym);
  mrb_define_class_under(mrb, kls, name,mrb_class_ptr(sc));  
  return mod;
}

void
mrb_girbind_gem_init(mrb_state* mrb) {
  struct RClass *obj = mrb_class_get(mrb,"Object");
  struct RClass *cls = mrb_class_get(mrb,"Class");
  struct RClass *gb = mrb_define_module_under(mrb, obj, "GirBind");  
  mrb_define_class_method(mrb, gb, "define_module", girbind_define_module, ARGS_REQ(2)); 
  mrb_define_class_method(mrb, gb, "define_class", girbind_define_class, ARGS_REQ(2));
}

void
mrb_girbind_gem_final(mrb_state* mrb) {
  // finalize
}
