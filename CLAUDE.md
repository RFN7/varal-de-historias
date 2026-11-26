# Pronta pra Contar · Varal de Histórias

Página de venda e inscrição do curso ao vivo "Pronta pra Contar" (Juçara Batichoti, Varal de Histórias),
no padrão do Eleva Open Boulder (RFN7/openboulder). Desenvolvido por RFN AI Engineering.

## Stack
- `index.html`: página de arquivo único (HTML + CSS + JS), dados no objeto `CONFIG`.
- `painel.html`: painel da equipe (Supabase Auth com e-mail e senha, lista, confirmação, Excel).
- Banco: Supabase, projeto `varal-de-historias` (`havplwmjqiiivqhnxsxv`, sa-east-1).
- Hospedagem: GitHub Pages, branch `gh-pages` → https://rfn7.github.io/varal-de-historias/
- `.github/workflows/manter-supabase.yml`: consulta diária para o plano grátis não pausar o projeto.
- Edge Function `avisar-pagamento` (`supabase/functions/`): e-mail aos organizadores quando a aluna toca em "Já fiz o Pix".
  Precisa do segredo `RESEND_API_KEY` (opcional `AVISO_REMETENTE`). Sem a chave, só o alerta do painel funciona.

## Fluxo de pagamento (opção A, aprovada em 26/11/2026)
1. Inscrição gravada com id gerado no navegador → tela do Pix (chave `CONFIG.pix`) com a bonequinha.
2. "Já fiz o Pix" → `varal_informar_pagamento(id, email)` + função `avisar-pagamento`.
3. Painel: tempo real (Realtime) + som + alerta "Pix para conferir"; reserva de 30 s.
4. Olavo confirma → a tela da aluna consulta `varal_status(id, email)` a cada 5 s e muda para "vaga garantida".
   A inscrição fica guardada no navegador (localStorage) para retomar se a aluna fechar e voltar.

## Regras do banco (não quebrar)
- O site só INSERE em `varal_inscricoes` (colunas do formulário). Nunca lê.
- Lote, valor e status são definidos pelo trigger `varal_define_lote` com a hora do servidor.
  Preço e prazo vivem só em `varal_lotes`. O `CONFIG.lotes` da página é só vitrine e deve bater com o banco.
- 1 inscrição ativa por e-mail (`teste` e `cancelado` não contam).
- Painel: só e-mails em `varal_organizadores` leem e atualizam.
- Schema: `supabase/migrations/` (20261125 inscrições, 20261126 aviso de pagamento).

## Estado atual (25/11/2026): MODO DE TESTE
- `CONFIG.previa = true`: faixa amarela, WhatsApp simulado, inscrições gravadas com `teste = true`.
- `noindex` ligado (meta robots). Juçara ainda não aprovou a divulgação.
- Organizador liberado: olavovirgilio@gmail.com.

## Para lançar de verdade
1. Confirmar com a Juçara: data/horário da aula, preço e prazo, Pix ou link de pagamento.
2. Atualizar `varal_lotes` no banco E `CONFIG.lotes` na página com os mesmos valores.
3. `CONFIG.previa = false`, remover a meta `robots noindex`.
4. Apagar as inscrições de teste: `delete from varal_inscricoes where teste;`
5. Supabase > Authentication > URL Configuration > Site URL = endereço final.
6. Publicar só com aprovação do Romero e da Juçara.
