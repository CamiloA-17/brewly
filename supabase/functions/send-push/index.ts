// Brewly · Edge Function "send-push"
// ---------------------------------------------------------------------------
// Se invoca mediante un Database Webhook de Supabase configurado en
// INSERT sobre public.notifications. Busca los tokens del destinatario y envía
// la notificación a APNs (Apple Push Notification service).
//
// Secretos requeridos (supabase secrets set ...):
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY (contenido .p8), APNS_BUNDLE_ID,
//   APNS_PRODUCTION ("true" | "false"), WEBHOOK_SECRET
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los inyecta Supabase automáticamente.

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

type NotificationRow = {
  id: string;
  recipient_id: string;
  actor_id: string;
  type: "follow" | "follow_request" | "follow_accepted" | "like" | "comment" | "reply" | "fork";
  post_id: string | null;
  comment_id: string | null;
  recipe_id: string | null;
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const MESSAGES: Record<NotificationRow["type"], (actor: string) => string> = {
  follow: (a) => `${a} comenzó a seguirte`,
  follow_request: (a) => `${a} quiere seguirte`,
  follow_accepted: (a) => `${a} aceptó tu solicitud`,
  like: (a) => `A ${a} le gustó tu publicación`,
  comment: (a) => `${a} comentó tu publicación`,
  reply: (a) => `${a} respondió a tu comentario`,
  fork: (a) => `${a} guardó una copia de tu receta`,
};

let cachedJwt: { token: string; issuedAt: number } | null = null;

async function apnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // Apple recomienda renovar el token entre 20 y 60 minutos.
  if (cachedJwt && now - cachedJwt.issuedAt < 50 * 60) return cachedJwt.token;
  const key = await importPKCS8(Deno.env.get("APNS_PRIVATE_KEY")!, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!)
    .setIssuedAt(now)
    .sign(key);
  cachedJwt = { token, issuedAt: now };
  return token;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("WEBHOOK_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }

  const { record } = (await req.json()) as { record: NotificationRow };

  const [{ data: actor }, { data: tokens }, { count: unread }] = await Promise.all([
    supabase.from("profiles").select("username").eq("id", record.actor_id).single(),
    supabase.from("push_tokens").select("token").eq("user_id", record.recipient_id),
    supabase.from("notifications").select("id", { count: "exact", head: true })
      .eq("recipient_id", record.recipient_id).is("read_at", null),
  ]);

  if (!tokens?.length) return new Response("no tokens", { status: 200 });

  const host = Deno.env.get("APNS_PRODUCTION") === "true"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
  const jwt = await apnsJwt();
  const payload = {
    aps: {
      alert: { title: "Brewly", body: MESSAGES[record.type](`@${actor?.username ?? "alguien"}`) },
      badge: unread ?? 0,
      sound: "default",
    },
    // Datos para el deep link en la app.
    notification_id: record.id,
    type: record.type,
    post_id: record.post_id,
    recipe_id: record.recipe_id,
    actor_id: record.actor_id,
  };

  const results = await Promise.all(tokens.map(async ({ token }) => {
    const res = await fetch(`${host}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
        "apns-push-type": "alert",
      },
      body: JSON.stringify(payload),
    });
    // 410 = el token ya no es válido (app desinstalada): se elimina.
    if (res.status === 410) await supabase.from("push_tokens").delete().eq("token", token);
    return res.status;
  }));

  return Response.json({ sent: results });
});
