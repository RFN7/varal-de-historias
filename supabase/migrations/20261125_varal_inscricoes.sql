-- Pronta pra Contar (Varal de Histórias): inscrições do curso.
-- Aplicado em 25/11/2026 no projeto Supabase varal-de-historias (havplwmjqiiivqhnxsxv)
-- como as migrações varal_inscricoes_inicial + varal_lote_atual_invoker.
-- Regra de ouro: o site só insere; preço e lote são decididos pelo banco.

create table public.varal_lotes (
  id serial primary key,
  nome text not null check (char_length(nome) between 2 and 40),
  de timestamptz not null,
  ate timestamptz not null,
  preco numeric(8,2) not null check (preco >= 0 and preco <= 5000),
  check (ate > de)
);
comment on table public.varal_lotes is 'Fonte única de preço e prazo. O site mostra; o banco cobra.';

insert into public.varal_lotes (nome, de, ate, preco)
values ('Valor único', '2026-11-24 00:00:00-03', '2026-12-09 12:00:00-03', 85);

create table public.varal_inscricoes (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  nome text not null check (char_length(nome) between 3 and 120),
  telefone text not null check (char_length(regexp_replace(telefone, '\D', '', 'g')) between 10 and 13),
  email text not null check (char_length(email) <= 160 and email ~* '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$'),
  cidade text not null check (char_length(cidade) between 2 and 80),
  perfil text not null check (char_length(perfil) between 2 and 80),
  nivel text not null check (nivel in ('Ainda não, quero começar','Às vezes, quero melhorar','Sempre, quero me profissionalizar')),
  obs text check (char_length(obs) <= 500),
  aceite boolean not null check (aceite),
  teste boolean not null default false,
  lote text,
  valor numeric(8,2),
  status text not null default 'pendente' check (status in ('pendente','confirmado','cancelado')),
  pagamento_confirmado_em timestamptz,
  link_enviado_em timestamptz,
  certificado_emitido_em timestamptz
);
comment on table public.varal_inscricoes is 'Inscrições do curso Pronta pra Contar. O site só insere; a equipe lê e confirma pelo painel.';

-- uma inscrição ativa por e-mail (inscrições de teste não contam)
create unique index varal_inscricoes_email_ativo
  on public.varal_inscricoes (lower(email))
  where status <> 'cancelado' and not teste;
create index varal_inscricoes_created_at on public.varal_inscricoes (created_at desc);

-- lote e valor calculados no servidor, com a hora do servidor
create or replace function public.varal_define_lote()
returns trigger language plpgsql security definer set search_path = public as $$
declare l public.varal_lotes%rowtype;
begin
  select * into l from public.varal_lotes
   where now() >= de and now() <= ate
   order by de limit 1;
  if not found then
    raise exception 'inscricoes_fechadas' using errcode = 'P0001';
  end if;
  new.lote := l.nome;
  new.valor := l.preco;
  new.status := 'pendente';
  new.email := lower(trim(new.email));
  new.created_at := now();
  return new;
end $$;
revoke all on function public.varal_define_lote() from public, anon, authenticated;

create trigger varal_define_lote before insert on public.varal_inscricoes
  for each row execute function public.varal_define_lote();

-- organização (equipe do Varal com login)
create table public.varal_organizadores (email text primary key);

create or replace function public.varal_is_organizador()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.varal_organizadores where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;
revoke all on function public.varal_is_organizador() from public, anon;
grant execute on function public.varal_is_organizador() to authenticated;

-- RLS
alter table public.varal_lotes enable row level security;
alter table public.varal_inscricoes enable row level security;
alter table public.varal_organizadores enable row level security;

-- privilégios: começa do zero e libera só o necessário
revoke all on public.varal_lotes, public.varal_inscricoes, public.varal_organizadores from anon, authenticated;
revoke all on sequence public.varal_lotes_id_seq from anon, authenticated;

grant select on public.varal_lotes to anon, authenticated;
create policy "todos veem lotes" on public.varal_lotes for select to anon, authenticated using (true);
grant update on public.varal_lotes to authenticated;
create policy "organizacao ajusta lotes" on public.varal_lotes for update to authenticated
  using (public.varal_is_organizador()) with check (public.varal_is_organizador());

-- o site só preenche os campos do formulário
grant insert (nome, telefone, email, cidade, perfil, nivel, obs, aceite, teste) on public.varal_inscricoes to anon;
create policy "site insere inscricoes pendentes" on public.varal_inscricoes for insert to anon
  with check (status = 'pendente');

grant select, update (status, pagamento_confirmado_em, link_enviado_em, certificado_emitido_em, obs) on public.varal_inscricoes to authenticated;
create policy "organizacao le inscricoes" on public.varal_inscricoes for select to authenticated
  using (public.varal_is_organizador());
create policy "organizacao atualiza inscricoes" on public.varal_inscricoes for update to authenticated
  using (public.varal_is_organizador()) with check (public.varal_is_organizador());

grant select on public.varal_organizadores to authenticated;
create policy "organizador ve a si mesmo" on public.varal_organizadores for select to authenticated
  using (email = lower(coalesce(auth.jwt() ->> 'email', '')));

-- leitura pública só do lote aberto agora
create or replace function public.varal_lote_atual()
returns table (nome text, preco numeric, ate timestamptz)
language sql stable security invoker set search_path = public as $$
  select nome, preco, ate from public.varal_lotes where now() between de and ate order by de limit 1;
$$;
revoke all on function public.varal_lote_atual() from public;
grant execute on function public.varal_lote_atual() to anon, authenticated;

-- Liberar alguém no painel (rodar no SQL Editor):
--   insert into public.varal_organizadores(email) values ('pessoa@email.com');
