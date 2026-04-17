const axios = require('axios');

const BEON_BASE_URL = process.env.BEON_API_URL;
const BEON_TOKEN = process.env.BEON_TOKEN;

let otpLength = 6;

const setOtpLength = (length) => {
    otpLength = length;
};

const getOtpLength = () => {
    return otpLength;
};

const baseRequest = () => {
    return axios.create({
        baseURL: BEON_BASE_URL,
        headers: {
            'beon-token': BEON_TOKEN
        }
    });
};

const sendCustomCode = async (code, phoneNumber) => {
    try {
        const response = await baseRequest().post("messages/otp", {
            phoneNumber: phoneNumber,
            name: 'Squad',
            custom_code: code.toString(),
            type: 'sms',
            lang: 'ar'
        });

        if (response.status === 200 && response.data.status === 200) {
            return true;
        }
    } catch (error) {
        console.error('Beon OTP failed:', error.response?.data || error.message);
    }
    return false;
};

module.exports = {
    sendCustomCode,
    setOtpLength,
    getOtpLength
};