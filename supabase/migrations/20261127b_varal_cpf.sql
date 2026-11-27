-- Aplicado em 27/11/2026 (migração varal_cpf).
-- CPF na inscrição (só dígitos), no lugar do código para acompanhar a inscrição.
alter table public.varal_inscricoes add column cpf text check (cpf ~ '^[0-9]{11}$');
create index varal_inscricoes_cpf on public.varal_inscricoes (cpf);

grant insert (cpf) on public.varal_inscricoes to anon;
grant update (cpf) on public.varal_inscricoes to authenticated;

-- acompanhar a inscrição em outro aparelho: CPF + e-mail
create or replace function public.varal_buscar_por_cpf(p_cpf text, p_email text)
returns table (id uuid, nome text, status text, informado boolean)
language sql stable security definer set search_path = public as $$
  select i.id, split_part(i.nome, ' ', 1), i.status, i.pagamento_informado_em is not null
    from public.varal_inscricoes i
   where i.cpf = regexp_replace(coalesce(p_cpf,''), '\D', '', 'g')
     and i.email = lower(trim(p_email))
   order by i.created_at desc
   limit 1;
$$;
revoke all on function public.varal_buscar_por_cpf(text, text) from public;
grant execute on function public.varal_buscar_por_cpf(text, text) to anon, authenticated;
