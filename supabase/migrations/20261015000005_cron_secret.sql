-- Scheduled jobs (pg_cron + pg_net) call Edge Functions with a random secret
-- that is generated here, inside the database, and kept in Vault. Nobody has to
-- copy it: cron reads it from vault.decrypted_secrets and the functions check
-- it with check_cron_secret(). Works with the new sb_secret_/sb_publishable_
-- API keys, which are not JWTs.

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'closer_cron_secret') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'closer_cron_secret',
      'Bearer token for scheduled calls to Closer Edge Functions'
    );
  end if;
end;
$$;

-- Compares hashes, so the comparison time does not depend on the secret.
create function public.check_cron_secret(p_secret text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select extensions.digest(p_secret, 'sha256')
         = extensions.digest(decrypted_secret, 'sha256')
    from vault.decrypted_secrets
    where name = 'closer_cron_secret'
  ), false)
  and coalesce(length(p_secret), 0) > 0;
$$;

revoke execute on function public.check_cron_secret(text) from public, anon, authenticated;
grant execute on function public.check_cron_secret(text) to service_role;
