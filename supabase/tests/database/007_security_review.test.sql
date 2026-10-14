-- Phase 6 security review: schema-wide invariants that must hold for every
-- table, function and bucket, including ones added by future migrations.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Row level security everywhere.
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0, 'every public table has row level security');

-- Signed-out callers (anon) cannot touch any table directly.
select is(
  (select count(*)::int from information_schema.role_table_grants
   where grantee = 'anon' and table_schema = 'public'),
  0, 'anon has no table privileges in public');

-- ... nor call any function.
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  0, 'anon cannot execute any public function');

-- Signed-in users cannot call server-only functions.
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('claim_cleanup_jobs', 'complete_cleanup_job', 'expire_stale_uploads',
                       'grant_group_entitlement', 'revoke_group_entitlement',
                       'record_store_purchase', 'prepare_account_deletion',
                       'claim_push_batch', 'complete_push', 'enqueue_milestone_reminders')
     and has_function_privilege('authenticated', p.oid, 'execute')),
  0, 'server-only functions are not callable by signed-in users');

-- Every SECURITY DEFINER function pins its search_path.
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c
                     where c like 'search_path=%')),
  0, 'security definer functions set search_path');

-- No security definer function is owned by a role that clients can assume.
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and pg_get_userbyid(p.proowner) in ('anon', 'authenticated')),
  0, 'definer functions are not owned by client roles');

-- Private storage only.
select is(
  (select count(*)::int from storage.buckets where public),
  0, 'no public storage buckets');
select ok(
  (select bool_and(file_size_limit is not null and allowed_mime_types is not null)
   from storage.buckets),
  'every bucket limits file size and type');

-- Views run with the caller's permissions (RLS applies).
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'v'
     and not coalesce('security_invoker=true' = any(c.reloptions)
                      or 'security_invoker=on' = any(c.reloptions), false)),
  0, 'public views are security invoker');

select * from finish();
rollback;
