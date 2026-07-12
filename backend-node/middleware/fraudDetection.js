import axios from 'axios';

const FRAUD_API_URL = process.env.FRAUD_API_URL || 'http://localhost:8000';

export const runFraudCheck = async ({ senderUserId, recipientUserId, amountMinor, senderBalanceBefore, recipientBalanceBefore, type = 'TRANSFER' }) => {
  try {
    const amount = amountMinor / 100;
    const oldbalanceOrg = senderBalanceBefore / 100;
    const newbalanceOrig = (senderBalanceBefore - amountMinor) / 100;
    const oldbalanceDest = recipientBalanceBefore / 100;
    const newbalanceDest = (recipientBalanceBefore + amountMinor) / 100;

    const { data } = await axios.post(`${FRAUD_API_URL}/predict`, {
      step: 1,
      type,
      amount,
      oldbalanceOrg,
      newbalanceOrig,
      oldbalanceDest,
      newbalanceDest,
    }, { timeout: 5000 });

    return {
      passed: data.risk_level !== 'HIGH',
      isFraud: data.is_fraud,
      riskLevel: data.risk_level,
      probability: data.probability,
      reasons: data.reasons,
    };
  } catch (error) {
    console.error('Fraud detection API error:', error.message);
    return { passed: true, isFraud: false, riskLevel: 'LOW', probability: 0, reasons: [] };
  }
};
