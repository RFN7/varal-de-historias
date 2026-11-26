-- Aplicado em 26/11/2026 (migração varal_aviso_pagamento).
-- Pagamento no fim da inscrição (opção A): a aluna avisa que fez o Pix,
-- o Olavo é avisado (painel em tempo real + e-mail) e confirma.

alter table public.varal_inscricoes
  add column pagamento_informado_em timestamptz,
  add column aviso_enviado_em timestamptz;

-- o site gera o id da inscrição (uuid aleatório) para acompanhar o status depois
grant insert (id) on public.varal_inscricoes to anon;

-- a aluna avisa que pagou: só a própria inscrição (id + e-mail), só se pendente
create or replace function public.varal_informar_pagamento(p_id uuid, p_email text)
returns boolean language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update public.varal_inscricoes
     set pagamento_informado_em = coalesce(pagamento_informado_em, now())
   where id = p_id and email = lower(trim(p_email)) and status = 'pendente';
  get diagnostics n = row_count;
  return n > 0;
end $$;
revoke all on function public.varal_informar_pagamento(uuid, text) from public;
grant execute on function public.varal_informar_pagamento(uuid, text) to anon, authenticated;

-- a tela da aluna consulta só o status da própria inscrição
create or replace function public.varal_status(p_id uuid, p_email text)
returns text language sql stable security definer set search_path = public as $$
  select status from public.varal_inscricoes where id = p_id and email = lower(trim(p_email));
$$;
revoke all on function public.varal_status(uuid, text) from public;
grant execute on function public.varal_status(uuid, text) to anon, authenticated;

-- painel recebe mudanças em tempo real (o RLS continua valendo: só organizadores)
alter publication supabase_realtime add table public.varal_inscricoes;
