require("dotenv/config");
const axios = require("axios");

async function main() {
  const to = process.argv[2];

  if (!to) {
    console.log("Usage: node brevo-mail-test.js receiver@example.com");
    process.exit(1);
  }

  const apiKey = (process.env.BREVO_API_KEY || "").trim();
  const senderEmail = (process.env.BREVO_SENDER_EMAIL || "").trim();

  if (!apiKey.startsWith("xkeysib-")) {
    console.log("BREVO_API_KEY missing or wrong. It must start with xkeysib-");
    process.exit(1);
  }

  if (!senderEmail.includes("@")) {
    console.log("BREVO_SENDER_EMAIL missing or wrong.");
    process.exit(1);
  }

  await axios.post(
    "https://api.brevo.com/v3/smtp/email",
    {
      sender: {
        name: process.env.BREVO_SENDER_NAME || "CircleUp",
        email: senderEmail,
      },
      to: [{ email: to }],
      subject: "CircleUp Email Verification Test",
      htmlContent: `
        <div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;border:1px solid #e5e7eb;border-radius:18px">
          <h2 style="color:#4f46e5">CircleUp Email Test</h2>
          <p>Your CircleUp email verification service is working.</p>
        </div>
      `,
      textContent: "CircleUp email verification service is working.",
    },
    {
      headers: {
        accept: "application/json",
        "api-key": apiKey,
        "content-type": "application/json",
      },
    }
  );

  console.log("Email sent successfully. Check inbox/spam.");
}

main().catch((err) => {
  console.error("Email failed:");
  console.error(err.response?.data || err.message);
});
