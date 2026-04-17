const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

async function sendResetEmail({ to, resetUrl }) {
  await transporter.sendMail({
    from: process.env.MAIL_FROM || process.env.SMTP_USER,
    to,
    subject: "Reset your Squad Player password",
    html: `
      <p>You requested to reset your password.</p>
      <p><a href="${resetUrl}">Click here to reset your password</a></p>
      <p>This link expires soon. If you didn’t request it, ignore this email.</p>
    `,
  });
}

module.exports = { sendResetEmail };