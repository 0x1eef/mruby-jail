/*
** mrb_jail.c - FreeBSD Jail bindings for mruby
**
** Wraps libjail for jail_set(2), jail_get(2), jail_attach(2),
** and jail_remove(2).
*/

#include <sys/types.h>
#include <sys/param.h>
#include <sys/jail.h>
#include <sys/sysctl.h>
#include <jail.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mruby.h>
#include <mruby/error.h>
#include <mruby/string.h>
#include <mruby/hash.h>
#include <mruby/array.h>
#include <mruby/numeric.h>

#define MRB_JAIL_CREATE 0x01
#define MRB_JAIL_UPDATE 0x02
#define MRB_JAIL_ATTACH 0x04
#define MRB_JAIL_DYING 0x08

enum mrb_jail_value_kind {
  MRB_JAIL_VALUE_STRING = 0,
  MRB_JAIL_VALUE_INT = 1,
  MRB_JAIL_VALUE_BOOL = 2
};

struct mrb_jail_params {
  struct jailparam *params;
  unsigned count;
  enum mrb_jail_value_kind *kinds;
};

static void
mrb_jail_params_free(struct mrb_jail_params *jp)
{
  if (!jp) return;
  if (jp->params) jailparam_free(jp->params, jp->count);
  free(jp->params);
  free(jp->kinds);
  free(jp);
}

static int
mrb_jail_value_is_output(const char *key, mrb_value val)
{
  if (mrb_nil_p(val)) return 1;
  switch (mrb_type(val)) {
  case MRB_TT_STRING:
    return RSTRING_LEN(val) == 0;
  case MRB_TT_FALSE:
    return strcmp(key, "lastjid") != 0;
  case MRB_TT_TRUE:
    return 0;
  case MRB_TT_FIXNUM:
    if (strcmp(key, "lastjid") == 0) return 0;
    return mrb_fixnum(val) == 0;
  default:
    return 0;
  }
}

static enum mrb_jail_value_kind
mrb_jail_param_kind(struct jailparam *param, mrb_value val, mrb_bool for_get)
{
  if (for_get && mrb_nil_p(val)) {
    if (param->jp_flags & JP_BOOL) return MRB_JAIL_VALUE_BOOL;
    switch (param->jp_ctltype) {
    case CTLTYPE_INT:
    case CTLTYPE_UINT:
    case CTLTYPE_LONG:
    case CTLTYPE_ULONG:
    case CTLTYPE_S64:
    case CTLTYPE_U64:
    case CTLTYPE_U8:
    case CTLTYPE_U16:
    case CTLTYPE_S8:
    case CTLTYPE_S16:
    case CTLTYPE_S32:
    case CTLTYPE_U32:
      return MRB_JAIL_VALUE_INT;
    default:
      return MRB_JAIL_VALUE_STRING;
    }
  }
  switch (mrb_type(val)) {
  case MRB_TT_TRUE:
  case MRB_TT_FALSE:
    return MRB_JAIL_VALUE_BOOL;
  case MRB_TT_FIXNUM:
    return MRB_JAIL_VALUE_INT;
  default:
    return MRB_JAIL_VALUE_STRING;
  }
}

static void
mrb_jail_import_value(mrb_state *mrb, struct jailparam *param, mrb_value val)
{
  switch (mrb_type(val)) {
  case MRB_TT_TRUE:
    {
      if (jailparam_import(param, "true") == -1) mrb_sys_fail(mrb, "jailparam_import");
    }
    break;
  case MRB_TT_FALSE:
    {
      if (jailparam_import(param, "false") == -1) mrb_sys_fail(mrb, "jailparam_import");
    }
    break;
  case MRB_TT_FIXNUM:
    {
      char buf[32];
      snprintf(buf, sizeof(buf), "%ld", (long)mrb_fixnum(val));
      if (jailparam_import(param, buf) == -1) mrb_sys_fail(mrb, "jailparam_import");
    }
    break;
  default:
    {
      mrb_value s = mrb_string_type(mrb, val);
      const char *cstr = mrb_string_value_cstr(mrb, &s);
      if (jailparam_import(param, cstr) == -1) mrb_sys_fail(mrb, "jailparam_import");
    }
    break;
  }
}

static struct mrb_jail_params*
mrb_jail_params_build(mrb_state *mrb, mrb_value hash, mrb_bool for_get)
{
  struct mrb_jail_params *jp;
  mrb_value keys;
  size_t i;

  jp = (struct mrb_jail_params *)calloc(1, sizeof(*jp));
  if (!jp) mrb_raise(mrb, E_RUNTIME_ERROR, "calloc failed");

  keys = mrb_hash_keys(mrb, hash);
  jp->count = (unsigned)RARRAY_LEN(keys);
  jp->params = (struct jailparam *)calloc(jp->count, sizeof(struct jailparam));
  jp->kinds = (enum mrb_jail_value_kind *)calloc(jp->count, sizeof(enum mrb_jail_value_kind));
  if (!jp->params || !jp->kinds) {
    mrb_jail_params_free(jp);
    mrb_raise(mrb, E_RUNTIME_ERROR, "calloc failed");
  }

  for (i = 0; i < jp->count; i++) {
    mrb_value key = mrb_ary_ref(mrb, keys, (mrb_int)i);
    mrb_value val = mrb_hash_get(mrb, hash, key);
    mrb_value key_str = mrb_string_type(mrb, key);
    const char *name = mrb_string_value_cstr(mrb, &key_str);

    if (jailparam_init(&jp->params[i], name) == -1) {
      mrb_jail_params_free(jp);
      mrb_sys_fail(mrb, "jailparam_init");
    }

    jp->kinds[i] = mrb_jail_param_kind(&jp->params[i], val, for_get);
    if (!for_get || !mrb_jail_value_is_output(name, val)) {
      mrb_jail_import_value(mrb, &jp->params[i], val);
    }
  }

  return jp;
}

static mrb_value
mrb_jail_params_to_hash(mrb_state *mrb, struct mrb_jail_params *jp)
{
  mrb_value hash = mrb_hash_new(mrb);
  unsigned i;

  for (i = 0; i < jp->count; i++) {
    mrb_value key = mrb_str_new_cstr(mrb, jp->params[i].jp_name);
    mrb_value val;
    char *exported = jailparam_export(&jp->params[i]);

    if (!exported) mrb_sys_fail(mrb, "jailparam_export");

    switch (jp->kinds[i]) {
    case MRB_JAIL_VALUE_BOOL:
      val = mrb_fixnum_value((strcmp(exported, "true") == 0 || strcmp(exported, "1") == 0) ? 1 : 0);
      break;
    case MRB_JAIL_VALUE_INT:
      val = mrb_fixnum_value((mrb_int)strtol(exported, NULL, 10));
      break;
    default:
      val = mrb_str_new_cstr(mrb, exported);
      break;
    }

    free(exported);
    mrb_hash_set(mrb, hash, key, val);
  }

  return hash;
}

static mrb_value
mrb_jail_set(mrb_state *mrb, mrb_value self)
{
  mrb_value hash;
  mrb_int flags = 0;
  struct mrb_jail_params *jp;
  int jid;

  (void)self;
  mrb_get_args(mrb, "H|i", &hash, &flags);
  jp = mrb_jail_params_build(mrb, hash, 0);
  jid = jailparam_set(jp->params, jp->count, (int)flags);
  if (jid == -1) {
    mrb_jail_params_free(jp);
    mrb_sys_fail(mrb, "jailparam_set");
  }
  mrb_jail_params_free(jp);
  return mrb_fixnum_value((mrb_int)jid);
}

static mrb_value
mrb_jail_get(mrb_state *mrb, mrb_value self)
{
  mrb_value hash;
  mrb_int flags = 0;
  struct mrb_jail_params *jp;
  mrb_value result;

  (void)self;
  mrb_get_args(mrb, "H|i", &hash, &flags);
  jp = mrb_jail_params_build(mrb, hash, 1);
  if (jailparam_get(jp->params, jp->count, (int)flags) == -1) {
    mrb_jail_params_free(jp);
    mrb_sys_fail(mrb, "jailparam_get");
  }
  result = mrb_jail_params_to_hash(mrb, jp);
  mrb_jail_params_free(jp);
  return result;
}

static mrb_value
mrb_jail_attach(mrb_state *mrb, mrb_value self)
{
  mrb_int jid;

  (void)self;
  mrb_get_args(mrb, "i", &jid);
  if (jail_attach((int)jid) == -1) mrb_sys_fail(mrb, "jail_attach");
  return mrb_nil_value();
}

static mrb_value
mrb_jail_remove(mrb_state *mrb, mrb_value self)
{
  mrb_int jid;

  (void)self;
  mrb_get_args(mrb, "i", &jid);
  if (jail_remove((int)jid) == -1) mrb_sys_fail(mrb, "jail_remove");
  return mrb_nil_value();
}

static mrb_value
mrb_jail_constants(mrb_state *mrb, mrb_value self)
{
  mrb_value flags = mrb_hash_new(mrb);

  (void)self;
  mrb_hash_set(mrb, flags, mrb_symbol_value(mrb_intern_lit(mrb, "create")), mrb_fixnum_value(MRB_JAIL_CREATE));
  mrb_hash_set(mrb, flags, mrb_symbol_value(mrb_intern_lit(mrb, "update")), mrb_fixnum_value(MRB_JAIL_UPDATE));
  mrb_hash_set(mrb, flags, mrb_symbol_value(mrb_intern_lit(mrb, "attach")), mrb_fixnum_value(MRB_JAIL_ATTACH));
  mrb_hash_set(mrb, flags, mrb_symbol_value(mrb_intern_lit(mrb, "dying")), mrb_fixnum_value(MRB_JAIL_DYING));
  return flags;
}

void
mrb_mruby_jail_gem_init(mrb_state *mrb)
{
  struct RClass *jail_cls;

  jail_cls = mrb_define_class(mrb, "Jail", mrb->object_class);
  mrb_define_class_method(mrb, jail_cls, "set", mrb_jail_set, MRB_ARGS_ARG(1, 1));
  mrb_define_class_method(mrb, jail_cls, "get", mrb_jail_get, MRB_ARGS_ARG(1, 1));
  mrb_define_class_method(mrb, jail_cls, "attach", mrb_jail_attach, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, jail_cls, "remove", mrb_jail_remove, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, jail_cls, "flags", mrb_jail_constants, MRB_ARGS_NONE());
  mrb_define_const(mrb, jail_cls, "CREATE", mrb_fixnum_value(MRB_JAIL_CREATE));
  mrb_define_const(mrb, jail_cls, "UPDATE", mrb_fixnum_value(MRB_JAIL_UPDATE));
  mrb_define_const(mrb, jail_cls, "ATTACH", mrb_fixnum_value(MRB_JAIL_ATTACH));
  mrb_define_const(mrb, jail_cls, "DYING", mrb_fixnum_value(MRB_JAIL_DYING));
}

void
mrb_mruby_jail_gem_final(mrb_state *mrb)
{
  (void)mrb;
}
