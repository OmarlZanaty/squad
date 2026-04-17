const axios = require('axios');

const WHATSAPP_URL = process.env.WHATSAPP_API_URL;
const WHATSAPP_APPKEY = process.env.WHATSAPP_APPKEY;
const WHATSAPP_AUTHKEY = process.env.WHATSAPP_AUTHKEY;

const send = async (phone, otp) => {
    let normalized_phone = phone.replace(/^\+/, '').replace(/^20/, '').replace(/^0/, '');
    normalized_phone = '20' + normalized_phone;
    const message = "كود تسجيل الدخول الخاص بك هو: " + otp + "\nلأمانك، لا تشارك هذا الكود.";

    try {
        console.log('Sending WhatsApp OTP to:', normalized_phone);
        const data = {
            appkey: WHATSAPP_APPKEY,
            authkey: WHATSAPP_AUTHKEY,
            to: normalized_phone,
            message: message,
        };
        const response = await axios.post(WHATSAPP_URL, data, {
            headers: {
                'Content-Type': 'application/json',
            },
        });

        const result = response.data;
        if (response.status === 200 && result.message_status === 'Success') {
            return { message: 'OTP sent to your WhatsApp', status: 200, success: true };
        } else {
            const errorMessage = result.message || 'Unknown error';
            return { message: 'Failed to send WhatsApp OTP: ' + errorMessage , status: 405 };
        }
    } catch (error) {
           console.error('WhatsApp OTP send error in catch :', error);
        const errorMessage = error.response?.data?.message || error.message || 'Unknown error';
        return {  message: 'Failed to send WhatsApp OTP: ' + errorMessage , status: 405 };
    }
};


module.exports = {
    send,
};