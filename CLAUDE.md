# Pronta pra Contar · Varal de Histórias

Página de venda e inscrição do curso ao vivo "Pronta pra Contar" (Juçara Batichoti, Varal de Histórias),
no padrão do Eleva Open Boulder (RFN7/openboulder). Desenvolvido por RFN AI Engineering.

## Stack
- `index.html`: página de arquivo único (HTML + CSS + JS), dados no objeto `CONFIG`.
- `painel.html`: painel da equipe (Supabase Auth com e-mail e senha, lista, confirmação, Excel).
- Banco: Supabase, projeto `varal-de-historias` (`havplwmjqiiivqhnxsxv`, sa-east-1).
- Hospedagem: GitHub Pages, branch `gh-pages` → https://rfn7.github.io/varal-de-historias/
- `.github/workflows/manter-supabase.yml`: consulta diária para o plano grátis não pausar o projeto.

## Regras do banco (não quebrar)
- O site só INSERE em `varal_inscricoes` (colunas do formulário). Nunca lê.
- Lote, valor e status são definidos pelo trigger `varal_define_lote` com a hora do servidor.
  Preço e prazo vivem só em `varal_lotes`. O `CONFIG.lotes` da página é só vitrine e deve bater com o banco.
- 1 inscrição ativa por e-mail (`teste` e `cancelado` não contam).
- Painel: só e-mails em `varal_organizadores` leem e atualizam.
- Schema completo: `supabase/migrations/20261125_varal_inscricoes.sql`.

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
