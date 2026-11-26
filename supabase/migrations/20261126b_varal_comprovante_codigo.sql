-- Aplicado em 26/11/2026 (migração varal_comprovante_e_codigo).
-- Comprovante opcional + código da inscrição (padrão Eleva), sem mudar o fluxo atual.

alter table public.varal_inscricoes add column comprovante text check (char_length(comprovante) <= 200);

-- pasta privada: o site só envia; só organizadores leem
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('varal-comprovantes', 'varal-comprovantes', false, 5242880,
        array['image/jpeg','image/png','image/webp','image/heic','image/heif','application/pdf'])
on conflict (id) do nothing;

create policy "varal site envia comprovantes" on storage.objects for insert to anon
  with check (bucket_id = 'varal-comprovantes');
create policy "varal organizacao ve comprovantes" on storage.objects for select to authenticated
  using (bucket_id = 'varal-comprovantes' and public.varal_is_organizador());

-- liga o arquivo à inscrição (id + e-mail; só a própria pasta; só se pendente)
create or replace function public.varal_anexar_comprovante(p_id uuid, p_email text, p_caminho text)
returns boolean language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if p_caminho is null or p_caminho not like p_id::text || '/%' or char_length(p_caminho) > 200 then
    return false;
  end if;
  update public.varal_inscricoes set comprovante = p_caminho
   where id = p_id and email = lower(trim(p_email)) and status = 'pendente';
  get diagnostics n = row_count;
  return n > 0;
end $$;
revoke all on function public.varal_anexar_comprovante(uuid, text, text) from public;
grant execute on function public.varal_anexar_comprovante(uuid, text, text) to anon, authenticated;

-- acompanhar a inscrição em outro aparelho: código (8 primeiros caracteres do id) + e-mail
create or replace function public.varal_buscar_inscricao(p_codigo text, p_email text)
returns table (id uuid, nome text, status text, informado boolean)
language sql stable security definer set search_path = public as $$
  select i.id, split_part(i.nome, ' ', 1), i.status, i.pagamento_informado_em is not null
    from public.varal_inscricoes i
   where left(i.id::text, 8) = lower(trim(p_codigo))
     and i.email = lower(trim(p_email))
     and char_length(trim(p_codigo)) = 8
   limit 1;
$$;
revoke all on function public.varal_buscar_inscricao(text, text) from public;
grant execute on function public.varal_buscar_inscricao(text, text) to anon, authenticated;
