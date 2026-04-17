const db = require('../db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');


const { sendCustomCode } = require('../services/smsService');
const { send: sendWhatsApp } = require('../services/whatsappService');



const fs = require('fs');
const path = require('path');

const { saveToLocal } = require('../utils/localStorage');

exports.register = async (req, res) => {
    let {
        name,
        email,
        password,
        type,
        country,
        position,
        bio,
        current_club,
        weight,
        height,
        age,
        full_name,
        address,
        birth_date,
        phone
    } = req.body;

    if (!name || !phone  || !password || !type) {
        return res.status(400).json({ message: "الاسم ورقم التليفون وكلمة المرور ونوع الحساب مطلوبة." });
    }

    if (type === 'player') {
        if (!country || !position) {
            return res.status(400).json({ message: "لازم تختار الدولة والمركز للاعب." });
        }
        if (!weight || !height || !age) {
            return res.status(400).json({ message: "لازم تدخل الوزن والطول والعمر للاعب." });
        }
        if (!birth_date) {
            return res.status(400).json({ message: "لازم تكتب تاريخ الميلاد." });
        }
    }

    try {
      



        // Check if phone exists for the same type and is verified
if (phone && !phone.startsWith('placeholder_')) {

    const [phoneRows] = await db.query(
        "SELECT phone_verified FROM users WHERE phone = ? AND type = ?",
        [phone, type]
    );

    // Only block if phone exists AND is verified
    if (phoneRows.length > 0 && phoneRows[0].phone_verified === 1) {
        return res.status(409).json({
            message: "رقم الهاتف مسجل بالفعل"
        });
    }

}

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        const status = type === 'player' ? 'active' : 'active';

        if (!phone) {
            phone = 'placeholder_' + (Date.now() % 1e8).toString().padStart(8, '0');
        }

        // Insert into users
        const userSql = `INSERT INTO users (name, password, type, status, profile_photo_url, cover_photo_url, phone_verified, email, phone) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`;
        const [userResult] = await db.query(userSql, [name, hashedPassword, type, status, null, null, 0, email, phone]);
        const userId = userResult.insertId;

        // Insert into role table
        if (type === 'player') {
            const playerSql = `INSERT INTO players (user_id, country, position, bio, current_club, weight, height, age, full_name, national_id, birth_date, rating) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
            await db.query(playerSql, [userId, country, position, bio, current_club, weight, height, age, full_name, null, birth_date, 0.00]);
        } else if (type === 'scout') {
            const scoutSql = `INSERT INTO scouts (user_id) VALUES (?)`;
            await db.query(scoutSql, [userId]);
        } else if (type === 'guest') {
            const guestSql = `INSERT INTO guests (user_id) VALUES (?)`;
            await db.query(guestSql, [userId]);
        } else if (type === 'admin') {
            const adminSql = `INSERT INTO admins (user_id) VALUES (?)`;
            await db.query(adminSql, [userId]);
        }


        let message;
        if (type === 'player') {
            message = "تم إنشاء حساب اللاعب بنجاح! سيتم مراجعة حسابك والموافقة عليه قريباً.";
        } else if (type === 'scout') {
            message = "تم إنشاء حساب الكشاف بنجاح! يمكنك تسجيل الدخول الآن.";
        } else {
            message = "تم إنشاء الحساب بنجاح! يمكنك تسجيل الدخول الآن.";
        }

        return res.status(201).json({ success: true, message });

    } catch (error) {
        console.error("Registration Error:", error);

        // ✅ Duplicate phone/email handling
        if (error && error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ message: "البيانات مكررة. برجاء مراجعة البيانات المدخلة." });
        }

        return res.status(500).json({ message: "حدث خطأ في السيرفر أثناء إنشاء الحساب." });
    }

};

exports.login = async (req, res) => {
    const { email, phone, password, type } = req.body;

    // ✅ allow email OR phone
    if ((!email && !phone) || !password) {
        return res.status(400).json({
            message: "رقم الهاتف أو الإيميل مع كلمة المرور مطلوبين."
        });
    }

    try {
        let query;
        let params;

        if (phone) {
            // ✅ login using phone
            if (type) {
                query = "SELECT * FROM users WHERE phone = ? AND type = ?";
                params = [phone, type];
            } else {
                query = "SELECT * FROM users WHERE phone = ? AND type IN ('scout', 'guest')";
                params = [phone];
            }
        } else {
            // ✅ login using email
            if (type) {
                query = "SELECT * FROM users WHERE email = ? AND type = ?";
                params = [email, type];
            } else {
                query = "SELECT * FROM users WHERE email = ? AND type IN ('scout', 'guest')";
                params = [email];
            }
        }

        const [rows] = await db.query(query, params);

        if (rows.length === 0) {
            return res.status(401).json({ message: "بيانات الدخول غير صحيحة." });
        }

        const user = rows[0];

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ message: "بيانات الدخول غير صحيحة." });
        }

        if (user.type === 'player' && user.status !== 'active') {
            return res.status(403).json({
                message: "حسابك قيد المراجعة، رجاء الانتظار."
            });
        }

        const payload = {
            id: user.id,
            name: user.name,
            type: user.type
        };

        const token = jwt.sign(payload, process.env.JWT_SECRET, {
            expiresIn: '3d'
        });

        return res.status(200).json({
            message: "تم تسجيل الدخول بنجاح.",
            token,
            user: payload
        });

    } catch (error) {
        console.error("Login Error:", error);
        return res.status(500).json({
            message: "حدث خطأ في السيرفر أثناء تسجيل الدخول."
        });
    }
};

exports.getProfile = async (req, res) => {
    const userId = req.user.id;
    const type = req.user.type;

    try {
        let query;
        if (type === 'player') {
            query = `SELECT u.*, p.country, p.position, p.bio, p.current_club, p.weight, p.height, p.age, p.full_name, p.national_id, p.birth_date, p.rating FROM users u LEFT JOIN players p ON u.id = p.user_id WHERE u.id = ?`;
        } else if (type === 'scout') {
            query = `SELECT u.* FROM users u LEFT JOIN scouts s ON u.id = s.user_id WHERE u.id = ?`;
        } else if (type === 'guest') {
            query = `SELECT u.* FROM users u LEFT JOIN guests g ON u.id = g.user_id WHERE u.id = ?`;
        } else if (type === 'admin') {
            query = `SELECT u.* FROM users u LEFT JOIN admins a ON u.id = a.user_id WHERE u.id = ?`;
        } else {
            return res.status(400).json({ message: "نوع الحساب غير صحيح." });
        }

        const [rows] = await db.query(query, [userId]);

        if (rows.length === 0) {
            return res.status(404).json({ message: "هذا الرقم ليس مسجل لدينا, الرجاء إنشاء حساب جديد حتي تتمكن من الدخول علي التطبيق." });
        }

        return res.status(200).json(rows[0]);
    } catch (error) {
        console.error("Get Profile Error:", error);
        return res.status(500).json({ message: "حدث خطأ في السيرفر أثناء جلب بيانات الملف الشخصي." });
    }
};

exports.updateProfile = async (req, res) => {
    const userId = req.user.id;
const {
  name, bio, current_club, country, position, weight, height, age,
  full_name, address, birth_date, phone,
  cover_focus_x, cover_focus_y, profile_focus_x, profile_focus_y
} = req.body;

    console.log('Update Profile - Received data:');
    console.log('current_club:', current_club);
    console.log('req.body:', req.body);

    try {
        let updates = [];
        let values = [];

        // ✅ helper: parse focus (-1..1) safely
const toFocus = (v) => {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return Math.max(-1, Math.min(1, n));
};

        if (name) {
            updates.push("name = ?");
            values.push(name);
        }
        if (bio !== undefined) {
            updates.push("bio = ?");
            values.push(bio);
        }
        if (current_club !== undefined && current_club !== null) {
            updates.push("current_club = ?");
            values.push(current_club);
            console.log('Adding current_club to update:', current_club);
        }
        if (country) {
            updates.push("country = ?");
            values.push(country);
        }
        if (position) {
            updates.push("position = ?");
            values.push(position);
        }
        if (weight) {
            updates.push("weight = ?");
            values.push(weight);
        }
        if (height) {
            updates.push("height = ?");
            values.push(height);
        }
        if (age) {
            updates.push("age = ?");
            values.push(age);
        }
        if (full_name) {
            updates.push("full_name = ?");
            values.push(full_name);
        }
        if (address !== undefined) {
            updates.push("address = ?");
            values.push(address);
        }
        if (birth_date) {
            updates.push("birth_date = ?");
            values.push(birth_date);
        }
        if (phone) {
            updates.push("phone = ?");
            values.push(phone);
        }

        // ✅ Focus values (store in users table)
const cfx = toFocus(cover_focus_x);
if (cfx !== null) {
  updates.push("cover_focus_x = ?");
  values.push(cfx);
}

const cfy = toFocus(cover_focus_y);
if (cfy !== null) {
  updates.push("cover_focus_y = ?");
  values.push(cfy);
}

const pfx = toFocus(profile_focus_x);
if (pfx !== null) {
  updates.push("profile_focus_x = ?");
  values.push(pfx);
}

const pfy = toFocus(profile_focus_y);
if (pfy !== null) {
  updates.push("profile_focus_y = ?");
  values.push(pfy);
}
        // Handle file uploads if present
        if (req.files) {
            if (req.files.profile_photo) {
                console.log('Uploading profile photo to S3');
                const profileUrl = saveToLocal(req.files.profile_photo[0], 'profiles');
                updates.push("profile_photo_url = ?");
                values.push(profileUrl);
            }

            if (req.files.cover_photo) {
                console.log('Uploading cover photo to S3');
                const coverUrl = saveToLocal(req.files.cover_photo[0], 'covers');
                updates.push("cover_photo_url = ?");
                values.push(coverUrl);
            }
        }

        if (updates.length === 0) {
            return res.status(400).json({ message: "لا يوجد بيانات لتحديثها." });
        }

        // Separate updates for users and role tables
const userFields = [
  'name', 'profile_photo_url', 'cover_photo_url', 'email', 'phone',
  'cover_focus_x', 'cover_focus_y', 'profile_focus_x', 'profile_focus_y'
];     
   let userUpdates = [];
        let userValues = [];
        let roleUpdates = [];
        let roleValues = [];

        for (let i = 0; i < updates.length; i++) {
            const field = updates[i].split(' = ')[0];
            if (userFields.includes(field)) {
                userUpdates.push(updates[i]);
                userValues.push(values[i]);
            } else {
                roleUpdates.push(updates[i]);
                roleValues.push(values[i]);
            }
        }

        const type = req.user.type; // Assume type is in req.user

        if (userUpdates.length > 0) {
            const userSql = `UPDATE users SET ${userUpdates.join(', ')} WHERE id = ?`;
            await db.query(userSql, [...userValues, userId]);
        }

        if (roleUpdates.length > 0 && type === 'player') {
            const roleSql = `UPDATE players SET ${roleUpdates.join(', ')} WHERE user_id = ?`;
            await db.query(roleSql, [...roleValues, userId]);
        }

        return res.status(200).json({ message: "تم تعديل البيانات بنجاح." });

    } catch (error) {
        console.error("Update Profile Error:", error);
        return res.status(500).json({ message: "حدث خطأ في السيرفر أثناء تحديث البيانات.", error: error.message });
    }
};

exports.loginWithOtp = async (req, res) => {
    const { phone, firebaseUid } = req.body;
    const appType = req.headers['x-app-type'] || 'user'; // default to user

    if (!phone || !firebaseUid) {
        return res.status(400).json({ message: "بيانات غير صحيحة." });
    }

    try {
        // Build query with type filter
        let typeCondition;
        if (appType === 'player') {
            typeCondition = "AND u.type = 'player'";
        } else {
            typeCondition = "AND u.type IN ('scout', 'guest')";
        }
        const [rows] = await db.query(
            `SELECT u.*, p.country, p.position, p.bio, p.current_club, p.weight, p.height, p.age, p.full_name, p.national_id, p.birth_date, p.rating FROM users u LEFT JOIN players p ON u.id = p.user_id WHERE u.phone = ? ${typeCondition} LIMIT 1`,
            [phone]
        );

        if (rows.length === 0) {
            return res.status(404).json({ message: "هذا الرقم ليس مسجل لدينا, الرجاء إنشاء حساب جديد حتي تتمكن من الدخول علي التطبيق." });
        }

        const user = rows[0];

        // ⏳ Pending approval
        if (user.type === 'player' && user.status === 'pending') {
            return res.status(403).json({ message: "حسابك قيد المراجعة حالياً." });
        }

        // 🚫 Blocked (if you add later)
        if (user.is_blocked === 1) {
            return res.status(403).json({ message: "تم حظر الحساب." });
        }

        const payload = {
            id: user.id,
            name: user.name,
            type: user.type
        };

        const token = jwt.sign(payload, process.env.JWT_SECRET, {
            expiresIn: '3d'
        });

        return res.status(200).json({
            token,
            user: payload
        });

    } catch (error) {
        console.error('OTP Login Error:', error);
        return res.status(500).json({ message: "حدث خطأ في السيرفر." });
    }
};

exports.sendOtp = async (req, res) => {
    let { phone, verification_method } = req.body;
    const appType = req.headers['x-app-type'] || 'user'; // default to user

    // Validation
    const phoneRegex = /^([0-9\s\-\+\(\)]*)$/;
    if (!phone || !phoneRegex.test(phone) || phone.length < 10 || phone.length > 20) {
        return res.status(400).json({ message: "رقم الهاتف مطلوب ويجب أن يكون بين 10 و 20 حرفًا مع تنسيق صحيح." });
    }
    if (!verification_method || !['sms', 'whatsapp'].includes(verification_method)) {
        return res.status(400).json({ message: "طريقة التحقق مطلوبة ويجب أن تكون sms أو whatsapp." });
    }

    try {
        let otp;

        // Normalize phone number: remove leading + or 2, ensure starts with 0
        let normalizedPhone = phone.replace(/^\+?2?/, '');
        if (!normalizedPhone.startsWith('0')) {
            normalizedPhone = '0' + normalizedPhone;
        }
        // For sending, add +2
        normalizedPhone = '+2' + normalizedPhone;

        // Check if user exists for the specific type
        let typeCondition;
        if (appType === 'player') {
            typeCondition = "AND type = 'player'";
        } else {
            typeCondition = "AND type IN ('scout', 'guest')";
        }
        const [users] = await db.query(`SELECT id FROM users WHERE phone = ? ${typeCondition}`, [phone]);
        const userId = users.length > 0 ? users[0].id : null;

        if (!userId) {
            return res.status(404).json({ message: "هذا الرقم ليس مسجل لدينا, الرجاء إنشاء حساب جديد حتي تتمكن من الدخول علي التطبيق." });
        }

        // make sure that it has been at least 60 seconds since last OTP
        const otpInterval = 60; // seconds
        const [recentOtps] = await db.query(
            "SELECT created_at FROM otps WHERE phone = ? ORDER BY created_at DESC LIMIT 1",
            [phone]
        );

        if (recentOtps.length > 0) {
            const lastOtpTime = new Date(recentOtps[0].created_at);
            const now = new Date();
            const secondsPassed = Math.floor((now - lastOtpTime) / 1000);
            if (secondsPassed < otpInterval) {
                const remaining = otpInterval - secondsPassed;
                return res.status(429).json({ message: `لقد أرسلت رمز تحقق مؤخرًا. الرجاء الانتظار ${remaining} ثانية قبل طلب رمز جديد.` });
            }
        }

        const testingPhones = process.env.TESTING_PHONES ? process.env.TESTING_PHONES.split(',') : [];
        if (testingPhones.includes(normalizedPhone)) {
            otp = '123456';
        } else {
            otp = Math.floor(100000 + Math.random() * 900000).toString();
            // Normalize phone number
            const normalizedPhone = phone.startsWith('+') ? phone : '+' + phone;
            let result;

            if (verification_method === 'sms') {
                result = await sendCustomCode(otp, normalizedPhone);
            } else if (verification_method === 'whatsapp') {
                result = await sendWhatsApp(normalizedPhone, otp);
            }
            if (!result || (verification_method === 'whatsapp' && result.status !== 200)) {
                return res.status(500).json({ message: result.message || "فشل في إرسال رمز التحقق." });
            }
        }

        const expiresAt = new Date(Date.now() + 2 * 60 * 1000); // 2 minutes from now

        // Clean up expired OTPs for this phone
        await db.query("DELETE FROM otps WHERE phone = ? AND expires_at < NOW()", [phone]);

        // Insert OTP into database
        await db.query(
            "INSERT INTO otps (user_id, phone, otp_code, expires_at) VALUES (?, ?, ?, ?)",
            [userId, phone, otp, expiresAt]
        );

        if (process.env.APP_MODE !== 'production' || testingPhones.includes(phone)) {
            return res.status(200).json({ message: "تم إرسال رمز التحقق.", otp, success: true });
        }

        return res.status(200).json({ message: "تم إرسال رمز التحقق بنجاح.", success: true });

    } catch (error) {
        console.error('Send OTP Error:', error);
        return res.status(500).json({ message: "حدث خطأ في السيرفر." });
    }
};

exports.verifyOtp = async (req, res) => {
    const { phone, otp_code } = req.body;
    const appType = req.headers['x-app-type'] || 'user'; // default to user

    if (!phone || !otp_code) {
        return res.status(400).json({ message: "رقم الهاتف ورمز التحقق مطلوبان." });
    }

    try {
        // Find the OTP
        const [otps] = await db.query(
            "SELECT * FROM otps WHERE phone = ? AND otp_code = ? AND used = FALSE AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1",
            [phone, otp_code]
        );

        if (otps.length === 0) {
            return res.status(400).json({ message: "رمز التحقق غير صحيح أو منتهي الصلاحية." });
        }

        const otp = otps[0];

        // Mark OTP as used
        await db.query("UPDATE otps SET used = TRUE WHERE id = ?", [otp.id]);



        // Get user with type filter
        let typeCondition;
        if (appType === 'player') {
            typeCondition = "AND type = 'player'";
        } else {
            typeCondition = "AND type IN ('scout', 'guest')";
        }
        let user;
        if (otp.user_id) {
            const [users] = await db.query(`SELECT * FROM users WHERE id = ? ${typeCondition}`, [otp.user_id]);
            user = users[0];
        } else {
            const [users] = await db.query(`SELECT * FROM users WHERE phone = ? ${typeCondition}`, [phone]);
            user = users[0];
        }

        if (!user) {
            return res.status(404).json({ message: "هذا الرقم ليس مسجل لدينا, الرجاء إنشاء حساب جديد حتي تتمكن من الدخول علي التطبيق." });
        }

        // Mark phone as verified
        if (user.phone_verified !== 1) {
            await db.query("UPDATE users SET phone_verified = TRUE WHERE phone = ?", [phone]);
        }


        // Check user status
        if (user.type === 'player' && user.status === 'pending') {
            return res.status(403).json({ message: "حسابك قيد المراجعة حالياً." });
        }

        if (user.is_blocked === 1) {
            return res.status(403).json({ message: "تم حظر الحساب." });
        }

        // Generate JWT token
        const payload = {
            id: user.id,
            name: user.name,
            type: user.type
        };

        const token = jwt.sign(payload, process.env.JWT_SECRET, {
            expiresIn: '3d'
        });

        return res.status(200).json({
            message: "تم تسجيل الدخول بنجاح.",
            token,
            user: payload
        });

    } catch (error) {
        console.error('Verify OTP Error:', error);
        return res.status(500).json({ message: "حدث خطأ في السيرفر." });
    }
};

