// Avisa a equipe por e-mail (Resend) quando uma aluna toca em "Já fiz o Pix".
// A notificação no celular (ntfy) sai do navegador da aluna (index.html): pelo servidor
// compartilhado do Supabase a cota gratuita do ntfy estoura.
// Chamada pela página depois de varal_informar_pagamento. Faz a própria checagem:
// só envia se a inscrição existe (id + e-mail), está pendente, foi informada
// como paga e ainda não teve aviso (1 e-mail por inscrição, sem spam).
// Precisa do segredo RESEND_API_KEY (Supabase > Edge Functions > Secrets).
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const PAINEL = "https://cursos.varaldehistorias.com.br/painel.html";
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const esc = (v: unknown) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, motivo: "metodo" }, 405);

  let id = "", email = "";
  try { ({ id, email } = await req.json()); } catch { return json({ ok: false, motivo: "corpo" }, 400); }
  if (!/^[0-9a-f-]{36}$/i.test(String(id)) || !String(email).includes("@")) return json({ ok: false, motivo: "dados" }, 400);

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: r } = await db.from("varal_inscricoes")
    .select("id, nome, email, telefone, cidade, valor, status, teste, pagamento_informado_em, aviso_enviado_em")
    .eq("id", id).eq("email", String(email).trim().toLowerCase()).maybeSingle();
  if (!r || r.status !== "pendente" || !r.pagamento_informado_em) return json({ ok: false, motivo: "nao_aplicavel" });
  if (r.aviso_enviado_em) return json({ ok: true, motivo: "ja_avisado" });

  const key = Deno.env.get("RESEND_API_KEY");
  if (!key) return json({ ok: false, motivo: "sem_chave" });

  const { data: orgs } = await db.from("varal_organizadores").select("email");
  const para = (orgs ?? []).map((o) => o.email);
  if (!para.length) return json({ ok: false, motivo: "sem_organizador" });

  const valor = Number(r.valor ?? 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
  const wa = "https://wa.me/55" + String(r.telefone).replace(/\D/g, "").replace(/^55(?=\d{10,11}$)/, "");
  const html = `
    <div style="font-family:Arial,sans-serif;font-size:16px;color:#1f2a44;max-width:520px">
      <h2 style="color:#26408f;margin:0 0 8px">Novo Pix para conferir${r.teste ? " (TESTE)" : ""}</h2>
      <p><b>${esc(r.nome)}</b> avisou que pagou <b>${esc(valor)}</b> no curso Pronta pra Contar.</p>
      <p>Confira no extrato da Juçara se o Pix caiu e confirme no painel.</p>
      <p style="margin:20px 0"><a href="${PAINEL}" style="background:#3aa655;color:#fff;padding:12px 20px;border-radius:999px;text-decoration:none;font-weight:bold">Abrir o painel</a></p>
      <p style="color:#5d6478;font-size:14px">${esc(r.cidade)} · ${esc(r.telefone)} · <a href="${wa}">chamar no WhatsApp</a></p>
    </div>`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: Deno.env.get("AVISO_REMETENTE") ?? "Varal de Histórias <onboarding@resend.dev>",
      to: para,
      subject: `${r.teste ? "[TESTE] " : ""}Novo Pix para conferir: ${r.nome} (${valor})`,
      html,
    }),
  });
  if (!res.ok) { console.error("resend", res.status, await res.text()); return json({ ok: false, motivo: "falha_envio" }); }
  await db.from("varal_inscricoes").update({ aviso_enviado_em: new Date().toISOString() }).eq("id", r.id);
  return json({ ok: true });
});
