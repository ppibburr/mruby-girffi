#include <mruby.h>
#include <stdio.h>
#include <mruby/class.h>


void
mrb_mruby_girffi_gem_init(mrb_state* mrb) {
#ifndef MRB_INT64
  printf("mruby-girffi: Need MRB_INT64\n");
#endif
  int ai = mrb_gc_arena_save(mrb);
  mrb_gc_arena_restore(mrb,ai); 
}
void
mrb_mruby_girffi_gem_final(mrb_state* mrb) {
  // finalize
}
