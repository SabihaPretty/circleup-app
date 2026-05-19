require("dotenv/config");
const nodemailer = require("nodemailer");

async function main() {
  const to = process.argv[2];

  if (!to) {
    console.log("Usage: node mail-test.js receiver@example.com");
    process.exit(1);
  }

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || "false") === "true",
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to,
    subject: "CircleUp Email Verification Test",
    text: "CircleUp email verification service is working.",
  });

  console.log("Email sent successfully. Check inbox/spam.");
}

main().catch((err) => {
  console.error("Email failed:");
  console.error(err.message);
});
