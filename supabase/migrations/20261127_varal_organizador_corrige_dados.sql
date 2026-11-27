-- Aplicado em 27/11/2026 (migração varal_organizador_corrige_dados).
-- A equipe pode corrigir os dados da inscrição no painel (ex.: nome para o certificado).
-- Só organizadores (a política de update já exige varal_is_organizador()); as checagens da tabela continuam valendo.
grant update (nome, telefone, email, cidade, perfil, nivel) on public.varal_inscricoes to authenticated;
