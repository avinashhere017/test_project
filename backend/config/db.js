const dns = require('dns');
const mongoose = require('mongoose');

// Some ISPs (Reliance Jio in particular) fail to resolve the SRV/TXT records
// that mongodb+srv:// depends on, even though ordinary DNS lookups work fine.
// Forcing Node's resolver to a public DNS server works around it.
dns.setServers(['8.8.8.8', '1.1.1.1']);

async function connectDb() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('MongoDB connected');
}

module.exports = connectDb;
