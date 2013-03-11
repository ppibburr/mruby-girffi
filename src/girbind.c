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
  struct RClass *where = mrb_define_module_under(mrb, kls, name);  
  mrb_value obj;
  obj = mrb_obj_value(where);
  return obj;

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
  struct RClass *where = mrb_define_class_under(mrb, kls, name,mrb_class_ptr(sc));  

  mrb_value obj;
  obj = mrb_obj_value(where);
  return obj;
}

mrb_value
girbind_save_arena(mrb_state *mrb, mrb_value self)
{
  int ai;
  ai = mrb_gc_arena_save(mrb);
  mrb_value i;
  i = mrb_fixnum_value(ai);
  return i;
}

mrb_value
girbind_restore_arena(mrb_state *mrb, mrb_value self)
{
  int i;
  mrb_get_args(mrb,"i",&i);
  mrb_gc_arena_restore(mrb,i);
  return self;
}

void
mrb_mruby_girffi_gem_init(mrb_state* mrb) {
  int ai = mrb_gc_arena_save(mrb);
  struct RClass *obj = mrb_class_get(mrb,"Object");
  struct RClass *cls = mrb_class_get(mrb,"Class");
  struct RClass *gb = mrb_define_module_under(mrb, obj, "GirBind");  
  mrb_define_class_method(mrb, gb, "define_module", girbind_define_module, ARGS_REQ(2)); 
  mrb_define_class_method(mrb, gb, "define_class", girbind_define_class, ARGS_REQ(2));
  mrb_define_class_method(mrb,gb,"save",girbind_save_arena,ARGS_NONE());
  mrb_define_class_method(mrb,gb,"restore",girbind_save_arena,ARGS_REQ(1));
  mrb_gc_arena_restore(mrb,ai);
}

void
mrb_mruby_girffi_gem_final(mrb_state* mrb) {
  // finalize
}
