// İletişim formu: Turnstile doğrula, Resend ile e-posta gönder.
// Sırlar (wrangler secret put): RESEND_API_KEY, TURNSTILE_SECRET_KEY
// Değişkenler (wrangler.toml [vars]): ALLOWED_ORIGINS, MAIL_FROM, MAIL_TO

const LIMITS = { isim: 60, eposta: 120, mesaj: 2000 };

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowed = env.ALLOWED_ORIGINS.split(",").map((o) => o.trim());
    const cors = allowed.includes(origin)
      ? { "Access-Control-Allow-Origin": origin, Vary: "Origin" }
      : {};

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: { ...cors, "Access-Control-Allow-Methods": "POST", "Access-Control-Allow-Headers": "Content-Type" },
      });
    }
    if (request.method !== "POST") return json({ hata: "Sadece POST" }, 405, cors);
    if (!cors["Access-Control-Allow-Origin"]) return json({ hata: "Bu adresten gönderilemez" }, 403, cors);

    let form;
    try {
      form = await request.formData();
    } catch {
      return json({ hata: "Form okunamadı" }, 400, cors);
    }
    const isim = String(form.get("isim") || "").trim();
    const eposta = String(form.get("eposta") || "").trim();
    const mesaj = String(form.get("mesaj") || "").trim();
    const token = String(form.get("cf-turnstile-response") || "");

    if (!isim || !mesaj) return json({ hata: "Ad ve mesaj gerekli" }, 400, cors);
    if (isim.length > LIMITS.isim || eposta.length > LIMITS.eposta || mesaj.length > LIMITS.mesaj) {
      return json({ hata: "Alanlardan biri çok uzun" }, 400, cors);
    }
    if (eposta && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(eposta)) {
      return json({ hata: "E-posta adresi geçersiz" }, 400, cors);
    }

    const dogrulama = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      body: new URLSearchParams({
        secret: env.TURNSTILE_SECRET_KEY,
        response: token,
        remoteip: request.headers.get("CF-Connecting-IP") || "",
      }),
    }).then((r) => r.json());
    if (!dogrulama.success) return json({ hata: "Robot doğrulaması başarısız" }, 400, cors);

    const gonderim = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: env.MAIL_FROM,
        to: [env.MAIL_TO],
        ...(eposta ? { reply_to: eposta } : {}),
        subject: `Siteden mesaj: ${isim}`,
        text: `Ad: ${isim}\nE-posta: ${eposta || "-"}\n\n${mesaj}`,
      }),
    });
    if (!gonderim.ok) {
      console.log("Resend hatası", gonderim.status, await gonderim.text());
      return json({ hata: "E-posta gönderilemedi" }, 502, cors);
    }
    return json({ tamam: true }, 200, cors);
  },
};

function json(body, status, headers) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json; charset=utf-8" },
  });
}
