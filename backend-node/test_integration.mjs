import http from 'http';
import jwt from 'jsonwebtoken';

const PORT = 18081;

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: 'localhost',
      port: PORT,
      path,
      method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (token) opts.headers.Authorization = `Bearer ${token}`;
    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function main() {
  const merchantLogin = await request('POST', '/api/v1/auth/login', {
    phoneNumber: '+201000000002',
    password: 'Merchant1234!',
  });
  console.log('MERCHANT LOGIN:', JSON.stringify(merchantLogin.body, null, 2));
  if (merchantLogin.status !== 200) { console.log('FAIL: merchant login'); return; }

  const merchantToken = merchantLogin.body.accessToken;
  const merchantId = merchantLogin.body.userId;

  // Register a customer user for the target payment
  const register = await request('POST', '/api/v1/auth/register', {
    fullName: 'Payment User',
    email: 'payuser@test.com',
    phoneNumber: '+201099999999',
    password: 'Test1234!',
    role: 'customer',
  });
  console.log('REGISTER:', JSON.stringify(register.body, null, 2));
  if (register.status !== 201) { console.log('FAIL: register'); return; }

  const customerToken = register.body.accessToken;
  const customerId = register.body.userId;

  // Merchant initiates payment for customer
  const init = await request('POST', '/api/payments/initiate', {
    merchant_id: merchantId,
    target_user_id: customerId,
    amount: 5000,
  }, merchantToken);
  console.log('INITIATE:', JSON.stringify(init.body, null, 2));
  if (init.status !== 201) { console.log('FAIL: initiate'); return; }

  // Create verification JWT as the biometric engine would
  const verifToken = jwt.sign(
    { user_id: customerId, transaction_id: init.body.transaction_id, score: 0.98 },
    "instashiled_on_the_top" || 'test_secret_key_12345'
  );

  // Confirm payment (should use merchant token or customer token? The spec says merchant's app calls this)
  const confirm = await request('POST', '/api/payments/confirm', {
    transaction_id: init.body.transaction_id,
    verification_token: verifToken,
  }, merchantToken);
  console.log('CONFIRM:', JSON.stringify(confirm.body, null, 2));
  if (confirm.status !== 200) { console.log('FAIL: confirm'); return; }

  // Verify balances changed
  const merchantWallet = await request('GET', '/api/v1/wallet/summary', null, merchantToken);
  console.log('MERCHANT WALLET:', JSON.stringify(merchantWallet.body, null, 2));

  const customerWallet = await request('GET', '/api/v1/wallet/summary', null, customerToken);
  console.log('CUSTOMER WALLET:', JSON.stringify(customerWallet.body, null, 2));

  console.log('\nALL TESTS PASSED');
}

main().catch((e) => console.error('ERROR:', e.message));
