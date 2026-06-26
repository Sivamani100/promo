const https = require('https');

const url = 'https://lokoxgwymvvnxhmavuyv.supabase.co/rest/v1/';
const headers = {
  'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxva294Z3d5bXZ2bnhobWF2dXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDM3MTEsImV4cCI6MjA5NzE3OTcxMX0.gpQT_54GRBls2q3dpxsKt70tcEkRdDgGVvjocq79qMU'
};

https.get(url, { headers }, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
      const spec = JSON.parse(data);
      const notificationsDef = spec.definitions ? spec.definitions.notifications : null;
      if (notificationsDef) {
        console.log('Notifications columns:', Object.keys(notificationsDef.properties));
      } else {
        console.log('Notifications definition not found in schema');
      }
    } catch (e) {
      console.log('Parse error:', e);
    }
  });
}).on('error', (err) => {
  console.error('Request error:', err);
});
