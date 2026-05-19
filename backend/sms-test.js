require("dotenv/config");
const twilio = require("twilio");

async function main() {
  const to = process.argv[2];

  if (!to) {
    console.log("Usage: node sms-test.js +8801XXXXXXXXX");
    process.exit(1);
  }

  const client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );

  await client.messages.create({
    body: "CircleUp SMS verification service is working.",
    from: process.env.TWILIO_PHONE_NUMBER,
    to,
  });

  console.log("SMS sent successfully.");
}

main().catch((err) => {
  console.error("SMS failed:");
  console.error(err.message);
});
