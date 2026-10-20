-- The cron secret is generated in Vault and checked only by trusted code.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is(
  (select count(*)::int from vault.secrets where name = 'closer_cron_secret'),
  1, 'the cron secret exists in Vault');

select ok(
  (select length(decrypted_secret) = 64 from vault.decrypted_secrets
   where name = 'closer_cron_secret'),
  'it is 32 random bytes (hex)');

select ok(
  public.check_cron_secret(
    (select decrypted_secret from vault.decrypted_secrets where name = 'closer_cron_secret')),
  'the right secret is accepted');
select ok(not public.check_cron_secret('wrong'), 'a wrong secret is rejected');
select ok(not public.check_cron_secret(''), 'an empty secret is rejected');
select ok(not public.check_cron_secret(null), 'a missing secret is rejected');

select ok(not has_function_privilege('authenticated', 'public.check_cron_secret(text)', 'execute'),
  'signed-in users cannot probe the secret');
select ok(not has_function_privilege('anon', 'public.check_cron_secret(text)', 'execute'),
  'anon cannot probe the secret');
select ok(has_function_privilege('service_role', 'public.check_cron_secret(text)', 'execute'),
  'Edge Functions (service role) can check it');

select * from finish();
rollback;
