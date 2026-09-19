const mongoose = require('mongoose');

const itemSchema = new mongoose.Schema({
  barcode: { type: String, required: true, trim: true, index: true },
  name: { type: String, required: true, trim: true },
  brand: { type: String, trim: true },
  quantity: { type: String, trim: true },
  price: { type: String, trim: true },
  source: { type: String, trim: true },
  sourceImageUrl: { type: String, trim: true },
  productPhotoUrl: { type: String, required: true },
  barcodePhotoUrl: { type: String, required: true },
}, { timestamps: true });

module.exports = mongoose.model('Item', itemSchema);
