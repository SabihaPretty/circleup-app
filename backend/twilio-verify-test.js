require("dotenv/config");
const twilio = require("twilio");

async function main() {
  const to = process.argv[2];

  if (!to) {
    console.log("Usage: node twilio-verify-test.js +8801XXXXXXXXX");
    process.exit(1);
  }

  if (!process.env.TWILIO_ACCOUNT_SID || !process.env.TWILIO_ACCOUNT_SID.startsWith("AC")) {
    console.log("TWILIO_ACCOUNT_SID missing or wrong. It must start with AC.");
    process.exit(1);
  }

  if (!process.env.TWILIO_VERIFY_SERVICE_SID || !process.env.TWILIO_VERIFY_SERVICE_SID.startsWith("VA")) {
    console.log("TWILIO_VERIFY_SERVICE_SID missing or wrong. It must start with VA.");
    process.exit(1);
  }

  const client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );

  const verification = await client.verify.v2
    .services(process.env.TWILIO_VERIFY_SERVICE_SID)
    .verifications.create({
      to,
      channel: "sms",
    });

  console.log("Verification sent:", verification.status);
}

main().catch((err) => {
  console.error("Phone verification failed:");
  console.error(err.message);
});
